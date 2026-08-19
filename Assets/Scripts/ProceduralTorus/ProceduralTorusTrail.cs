using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// GPU-generated, animated tube trails.
///
/// The centerline lives in SegmentData. A compute pass animates the centerline,
/// another compute pass tessellates it into VertexData, and the URP shader draws
/// the resulting indexed triangle stream procedurally.
/// </summary>
public sealed class ProceduralTorusTrail : MonoBehaviour
{
    [StructLayout(LayoutKind.Sequential)]
    private struct SegmentData
    {
        public Vector3 initialPosition;
        public Vector3 position;
        public Vector3 direction;
        public Vector3 normal;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct VertexData
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector2 uv;
    }

    [Header("References")]
    [SerializeField] private ComputeShader trailCompute;
    [SerializeField] private Shader trailShader;
    private Material _trailMaterial;

    [Header("Topology")]
    [Min(1)] [SerializeField] private int trailCount = 128;
    [Min(1)] [SerializeField] private int segmentsPerTrail = 160;
    [Range(3, 64)] [SerializeField] private int sidesPerRing = 12;
    [Min(0.0001f)] [SerializeField] private float tubeRadius = 0.2f;
    [Range(0f, 1f)] [SerializeField] private float visibleLength = 0.7f;

    [Header("Centerline")]
    [SerializeField] private int seed = 1337;
    [Min(0f)] [SerializeField] private float initialSpread = 30f;
    [Min(0.0001f)] [SerializeField] private float centerlineNoiseScale = 0.01f;
    [Min(0f)] [SerializeField] private float centerlineStep = 2f;

    [Header("Motion")]
    [Min(0f)] [SerializeField] private float motionAmplitude = 1f;
    [Min(0f)] [SerializeField] private float motionFrequency = 0.08f;
    [Min(0.0001f)] [SerializeField] private float motionSpatialScale = 0.07f;
    [Min(0f)] [SerializeField] private float motionSpeed = 1f;

    [Header("Color")]
    [SerializeField] private Gradient[] gradients = new Gradient[0];
    [Min(2)] [SerializeField] private int paletteResolution = 128;
    [Min(0f)] [SerializeField] private float gradientChangeSpeed = 0.1f;
    [Min(0f)] [SerializeField] private float paletteWaveSpeed = 0.5f;
    [Min(0f)] [SerializeField] private float paletteSegmentPhase = 0.75f;
    [Min(0f)] [SerializeField] private float paletteTrailPhase = 0.001f;

    [Header("Appearance")]
    [SerializeField] private Color tint = Color.white;
    [SerializeField] private Color rimColor = Color.white;
    [Min(0.01f)] [SerializeField] private float rimPower = 3f;
    [Min(0f)] [SerializeField] private float emissionStrength = 0.1f;
    [Min(0f)] [SerializeField] private float pulseSpeed = 0.1f;
    [Range(0.001f, 1f)] [SerializeField] private float pulseWidth = 0.1f;
    [Min(0f)] [SerializeField] private float pulseIntensity = 1f;

    private static readonly int InitialPositionBufferId = Shader.PropertyToID("_InitialPositionBuffer");
    private static readonly int SegmentBufferId = Shader.PropertyToID("_SegmentBuffer");
    private static readonly int VertexBufferId = Shader.PropertyToID("_VertexBuffer");
    private static readonly int IndexBufferId = Shader.PropertyToID("_IndexBuffer");
    private static readonly int PaletteBufferId = Shader.PropertyToID("_Palette");
    private static readonly int MaxSegmentId = Shader.PropertyToID("_MaxSegment");
    private static readonly int SidesPerRingId = Shader.PropertyToID("_SidesPerRing");
    private static readonly int TubeRadiusId = Shader.PropertyToID("_TubeRadius");
    private static readonly int VisibleLengthId = Shader.PropertyToID("_VisibleLength");
    private static readonly int CenterlineNoiseScaleId = Shader.PropertyToID("_CenterlineNoiseScale");
    private static readonly int CenterlineStepId = Shader.PropertyToID("_CenterlineStep");
    private static readonly int MotionAmplitudeId = Shader.PropertyToID("_MotionAmplitude");
    private static readonly int MotionFrequencyId = Shader.PropertyToID("_MotionFrequency");
    private static readonly int MotionSpatialScaleId = Shader.PropertyToID("_MotionSpatialScale");
    private static readonly int MotionSpeedId = Shader.PropertyToID("_MotionSpeed");
    private static readonly int CurrentTimeId = Shader.PropertyToID("_TrailTime");
    private static readonly int NoiseSeedId = Shader.PropertyToID("_NoiseSeed");
    private static readonly int VerticesPerTrailId = Shader.PropertyToID("_VerticesPerTrail");
    private static readonly int PaletteSizeId = Shader.PropertyToID("_PaletteSize");
    private static readonly int BaseColorId = Shader.PropertyToID("_BaseColor");
    private static readonly int RimColorId = Shader.PropertyToID("_RimColor");
    private static readonly int RimPowerId = Shader.PropertyToID("_RimPower");
    private static readonly int EmissionStrengthId = Shader.PropertyToID("_EmissionStrength");
    private static readonly int PulseSpeedId = Shader.PropertyToID("_PulseSpeed");
    private static readonly int PulseWidthId = Shader.PropertyToID("_PulseWidth");
    private static readonly int PulseIntensityId = Shader.PropertyToID("_PulseIntensity");
    private static readonly int PaletteWaveSpeedId = Shader.PropertyToID("_PaletteWaveSpeed");
    private static readonly int PaletteSegmentPhaseId = Shader.PropertyToID("_PaletteSegmentPhase");
    private static readonly int PaletteTrailPhaseId = Shader.PropertyToID("_PaletteTrailPhase");
    private static readonly int TrailCountId = Shader.PropertyToID("_TrailCount");
    private static readonly int TotalSegmentCountId = Shader.PropertyToID("_TotalSegmentCount");
    private static readonly int TotalVertexCountId = Shader.PropertyToID("_TotalVertexCount");
    private static readonly int LocalToWorldId = Shader.PropertyToID("_LocalToWorld");

    private const int ComputeThreadGroupSize = 64;

    private ComputeBuffer initialPositionBuffer;
    private ComputeBuffer segmentBuffer;
    private ComputeBuffer vertexBuffer;
    private ComputeBuffer indexBuffer;
    private ComputeBuffer paletteBuffer;

    private Vector3[] initialPositions;
    private int[] indices;
    private Vector4[] palette;
    private int initializeKernel;
    private int animateKernel;
    private int tessellateKernel;
    private bool initialized;
    private bool buffersDirty = true;
    private bool reportedMissingReference;

    private int RingCount => segmentsPerTrail + 1;
    private int VerticesPerTrail => RingCount * sidesPerRing;
    private int SegmentsTotal => trailCount * RingCount;
    private int VerticesTotal => trailCount * VerticesPerTrail;

    private void Start()
    {
        InitializeIfNeeded();
    }

    private void Update()
    {
        if (!Application.isPlaying)
            return;

        InitializeIfNeeded();
        if (!initialized)
            return;

        UpdatePalette();
        AnimateSegments();
        TessellateVertices();
    }

    private void OnRenderObject()
    {
        if (!initialized || _trailMaterial == null || vertexBuffer == null)
            return;

        ApplyMaterialProperties();

        _trailMaterial.SetBuffer(IndexBufferId, indexBuffer);
        _trailMaterial.SetBuffer(VertexBufferId, vertexBuffer);
        _trailMaterial.SetBuffer(PaletteBufferId, paletteBuffer);
        _trailMaterial.SetInt(VerticesPerTrailId, VerticesPerTrail);
        _trailMaterial.SetInt(PaletteSizeId, paletteResolution);

        if (_trailMaterial.SetPass(0))
        {
            Graphics.DrawProceduralNow(
                MeshTopology.Triangles,
                indices.Length,
                trailCount);
        }
    }

    private void OnDisable()
    {
        ReleaseResources();
    }

    private void OnDestroy()
    {
        ReleaseResources();
    }

    private void OnValidate()
    {
        trailCount = Mathf.Max(1, trailCount);
        segmentsPerTrail = Mathf.Max(1, segmentsPerTrail);
        sidesPerRing = Mathf.Clamp(sidesPerRing, 3, 64);
        paletteResolution = Mathf.Max(2, paletteResolution);
        visibleLength = Mathf.Clamp01(visibleLength);

        if (Application.isPlaying)
            buffersDirty = true;
    }

    private void InitializeIfNeeded()
    {
        if (!buffersDirty && initialized)
            return;

        if (!trailCompute || !trailShader)
        {
            if (!reportedMissingReference)
            {
                Debug.LogWarning($"{nameof(ProceduralTorusTrail)} requires both a ComputeShader and a Material.", this);
                reportedMissingReference = true;
            }

            return;
        }

        reportedMissingReference = false;
        ReleaseResources();
        BuildInitialData();
        FindKernels();
        AllocateBuffers();
        BindComputeBuffers();
        InitializeSegments();

        buffersDirty = false;
        initialized = true;
    }

    private void FindKernels()
    {
        _trailMaterial = new Material(trailShader);
        initializeKernel = trailCompute.FindKernel("InitializeSegments");
        animateKernel = trailCompute.FindKernel("AnimateSegments");
        tessellateKernel = trailCompute.FindKernel("TessellateVertices");
    }

    private void BuildInitialData()
    {
        initialPositions = new Vector3[trailCount];
        indices = new int[segmentsPerTrail * sidesPerRing * 6];
        palette = new Vector4[paletteResolution];

        var random = new System.Random(seed);
        for (int i = 0; i < initialPositions.Length; i++)
        {
            Vector3 point;
            do
            {
                point = new Vector3(
                    NextRandomSigned(random),
                    NextRandomSigned(random),
                    NextRandomSigned(random));
            }
            while (point.sqrMagnitude > 1f || point.sqrMagnitude < 0.0001f);

            initialPositions[i] = point * initialSpread;
        }

        int writeIndex = 0;
        for (int segment = 0; segment < segmentsPerTrail; segment++)
        {
            int firstRing = segment * sidesPerRing;
            int secondRing = (segment + 1) * sidesPerRing;

            for (int side = 0; side < sidesPerRing; side++)
            {
                int nextSide = (side + 1) % sidesPerRing;
                int a = firstRing + side;
                int b = firstRing + nextSide;
                int c = secondRing + side;
                int d = secondRing + nextSide;

                indices[writeIndex++] = a;
                indices[writeIndex++] = c;
                indices[writeIndex++] = b;
                indices[writeIndex++] = b;
                indices[writeIndex++] = c;
                indices[writeIndex++] = d;
            }
        }
    }

    private void AllocateBuffers()
    {
        initialPositionBuffer = new ComputeBuffer(initialPositions.Length, Marshal.SizeOf<Vector3>(), ComputeBufferType.Structured);
        segmentBuffer = new ComputeBuffer(SegmentsTotal, Marshal.SizeOf<SegmentData>(), ComputeBufferType.Structured);
        vertexBuffer = new ComputeBuffer(VerticesTotal, Marshal.SizeOf<VertexData>(), ComputeBufferType.Structured);
        indexBuffer = new ComputeBuffer(indices.Length, sizeof(int), ComputeBufferType.Structured);
        paletteBuffer = new ComputeBuffer(paletteResolution, Marshal.SizeOf<Vector4>(), ComputeBufferType.Structured);

        initialPositionBuffer.SetData(initialPositions);
        indexBuffer.SetData(indices);
    }

    private void BindComputeBuffers()
    {
        trailCompute.SetBuffer(initializeKernel, InitialPositionBufferId, initialPositionBuffer);
        trailCompute.SetBuffer(initializeKernel, SegmentBufferId, segmentBuffer);

        trailCompute.SetBuffer(animateKernel, SegmentBufferId, segmentBuffer);

        trailCompute.SetBuffer(tessellateKernel, SegmentBufferId, segmentBuffer);
        trailCompute.SetBuffer(tessellateKernel, VertexBufferId, vertexBuffer);
    }

    private void InitializeSegments()
    {
        trailCompute.SetInt(TrailCountId, trailCount);
        trailCompute.SetInt(MaxSegmentId, segmentsPerTrail);
        trailCompute.SetInt(SidesPerRingId, sidesPerRing);
        trailCompute.SetFloat(CenterlineNoiseScaleId, centerlineNoiseScale);
        trailCompute.SetFloat(CenterlineStepId, centerlineStep);
        trailCompute.SetFloat(NoiseSeedId, seed);
        trailCompute.Dispatch(initializeKernel, DivideRoundUp(trailCount, ComputeThreadGroupSize), 1, 1);
    }

    private void AnimateSegments()
    {
        trailCompute.SetInt(TotalSegmentCountId, SegmentsTotal);
        trailCompute.SetFloat(MotionAmplitudeId, motionAmplitude);
        trailCompute.SetFloat(MotionFrequencyId, motionFrequency);
        trailCompute.SetFloat(MotionSpatialScaleId, motionSpatialScale);
        trailCompute.SetFloat(MotionSpeedId, motionSpeed);
        trailCompute.SetFloat(CurrentTimeId, Time.time);
        trailCompute.SetFloat(NoiseSeedId, seed);
        trailCompute.Dispatch(animateKernel, DivideRoundUp(SegmentsTotal, ComputeThreadGroupSize), 1, 1);
    }

    private void TessellateVertices()
    {
        trailCompute.SetInt(TotalVertexCountId, VerticesTotal);
        trailCompute.SetInt(MaxSegmentId, segmentsPerTrail);
        trailCompute.SetInt(SidesPerRingId, sidesPerRing);
        trailCompute.SetFloat(TubeRadiusId, tubeRadius);
        trailCompute.SetFloat(VisibleLengthId, visibleLength);
        trailCompute.Dispatch(tessellateKernel, DivideRoundUp(VerticesTotal, ComputeThreadGroupSize), 1, 1);
    }

    private void UpdatePalette()
    {
        EnsureGradients();

        float gradientPosition = Mathf.Repeat(Time.time * gradientChangeSpeed, gradients.Length);
        int fromIndex = Mathf.FloorToInt(gradientPosition);
        int toIndex = (fromIndex + 1) % gradients.Length;
        float blend = gradientPosition - fromIndex;

        for (int i = 0; i < palette.Length; i++)
        {
            float t = i / (palette.Length - 1f);
            Color from = gradients[fromIndex].Evaluate(t);
            Color to = gradients[toIndex].Evaluate(t);
            Color color = Color.Lerp(from, to, blend);
            palette[i] = new Vector4(color.r, color.g, color.b, color.a);
        }

        paletteBuffer.SetData(palette);
    }

    private void ApplyMaterialProperties()
    {
        _trailMaterial.SetColor(BaseColorId, tint);
        _trailMaterial.SetColor(RimColorId, rimColor);
        _trailMaterial.SetFloat(RimPowerId, rimPower);
        _trailMaterial.SetFloat(EmissionStrengthId, emissionStrength);
        _trailMaterial.SetFloat(PulseSpeedId, pulseSpeed);
        _trailMaterial.SetFloat(PulseWidthId, pulseWidth);
        _trailMaterial.SetFloat(PulseIntensityId, pulseIntensity);
        _trailMaterial.SetFloat(PaletteWaveSpeedId, paletteWaveSpeed);
        _trailMaterial.SetFloat(PaletteSegmentPhaseId, paletteSegmentPhase);
        _trailMaterial.SetFloat(PaletteTrailPhaseId, paletteTrailPhase);
        _trailMaterial.SetMatrix(LocalToWorldId, transform.localToWorldMatrix);
    }

    private void EnsureGradients()
    {
        if (gradients == null || gradients.Length == 0)
            gradients = new[] { CreateDefaultGradient() };

        for (int i = 0; i < gradients.Length; i++)
        {
            if (gradients[i] == null)
                gradients[i] = CreateDefaultGradient();
        }
    }

    private static Gradient CreateDefaultGradient()
    {
        var gradient = new Gradient();
        gradient.SetKeys(
            new[]
            {
                new GradientColorKey(new Color(0.1f, 0.8f, 1f), 0f),
                new GradientColorKey(new Color(1f, 0.15f, 0.8f), 1f)
            },
            new[]
            {
                new GradientAlphaKey(1f, 0f),
                new GradientAlphaKey(1f, 1f)
            });
        return gradient;
    }

    private void ReleaseResources()
    {
        CoreUtils.Destroy(_trailMaterial);
        Release(ref initialPositionBuffer);
        Release(ref segmentBuffer);
        Release(ref vertexBuffer);
        Release(ref indexBuffer);
        Release(ref paletteBuffer);
        initialized = false;
    }

    private static void Release(ref ComputeBuffer buffer)
    {
        if (buffer == null)
            return;

        buffer.Release();
        buffer = null;
    }

    private static int DivideRoundUp(int value, int divisor)
    {
        return (value + divisor - 1) / divisor;
    }

    private static float NextRandomSigned(System.Random random)
    {
        return (float)(random.NextDouble() * 2.0 - 1.0);
    }

    // Public setters make the main controls easy to connect to UI sliders or Timeline.
    public void SetLength(float value) => visibleLength = Mathf.Clamp01(value);
    public void SetRadius(float value) => tubeRadius = Mathf.Max(0.0001f, value);
    public void SetMotionFrequency(float value) => motionFrequency = Mathf.Max(0f, value);
    public void SetMotionAmplitude(float value) => motionAmplitude = Mathf.Max(0f, value);
    public void SetGradientChangeSpeed(float value) => gradientChangeSpeed = Mathf.Max(0f, value);

    public void Rebuild()
    {
        buffersDirty = true;
        InitializeIfNeeded();
    }
}
