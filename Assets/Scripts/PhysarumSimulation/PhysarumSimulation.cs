using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

[DisallowMultipleComponent]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public sealed class PhysarumSimulation : MonoBehaviour
{
    public enum Pattern
    {
        OrganicVeins,
        CoralGrowth,
        NeuralMesh,
        OrbitBloom,
        CellularFans
    }

    public enum SpawnShape
    {
        Random,
        Disc,
        Ring,
        HorizontalBand
    }

    public enum DisplayMode
    {
        Trail,
        Particles,
        TrailAndParticles
    }

    public enum FieldMode
    {
        SeekBright,
        SeekDark,
        FollowContoursClockwise,
        FollowContoursCounterClockwise
    }

    [Serializable]
    public struct SignalCurve
    {
        [Tooltip("Value used where the sensed trail is zero.")]
        public float constant;

        [Tooltip("Amount added as the sensed trail approaches one. May be negative.")]
        public float response;

        [Min(0.01f)]
        [Tooltip("Shape of the response to sensed trail. One is linear.")]
        public float exponent;

        public SignalCurve(float constant, float response, float exponent)
        {
            this.constant = constant;
            this.response = response;
            this.exponent = exponent;
        }
    }

    [Header("Assets (automatic when left empty)")]
    [SerializeField] private ComputeShader simulationCompute;
    [SerializeField] private Shader displayShader;
    
    [Header("Input")]
    [Tooltip("Optional grayscale field texture. Takes priority over Source Camera when assigned.")]
    [SerializeField] private Texture sourceTexture;
    [Tooltip("Camera used as a live field map. A target texture is created automatically when the camera has none.")]
    [SerializeField] private Camera sourceCamera;
    [Tooltip("Seek grayscale extrema or travel tangentially along grayscale contours.")]
    [SerializeField] private FieldMode fieldMode = FieldMode.SeekBright;
    [Tooltip("Steering response to the grayscale gradient. Set to zero to disable field steering.")]
    [Range(0f, 10f)] [SerializeField] private float fieldStrength = 3f;
    [Tooltip("Distance in simulation pixels used to estimate the grayscale gradient.")]
    [Range(0.5f, 64f)] [SerializeField] private float fieldGradientDistance = 4f;
    [Tooltip("Maximum field-driven heading change per simulation iteration.")]
    [Range(0f, 180f)] [SerializeField] private float fieldMaxTurnDegrees = 30f;
    [Tooltip("Expands or compresses grayscale contrast around middle gray before steering.")]
    [Range(0.1f, 8f)] [SerializeField] private float fieldContrast = 1f;
    [Tooltip("Positive values move faster in bright areas; negative values move faster in dark areas.")]
    [Range(-1f, 1f)] [SerializeField] private float fieldSpeedInfluence;
    [Tooltip("Flip this when the camera/texture field appears vertically mirrored.")]
    [SerializeField] private bool flipFieldY;

    [SerializeField] private Pattern selectedPattern = Pattern.OrganicVeins;
    [SerializeField, HideInInspector] private Pattern appliedPattern = Pattern.OrganicVeins;
    [Header("Simulation")]
    [SerializeField] private Vector2Int resolution = new Vector2Int(1024, 1024);
    [Min(1024)] [SerializeField] private int agentCount = 262144;
    [Range(1, 8)] [SerializeField] private int iterationsPerFrame = 2;
    [Min(0)] [SerializeField] private int seed = 1337;
    [SerializeField] private bool paused;

    [SerializeField] private SpawnShape spawnShape = SpawnShape.Disc;
    [SerializeField, HideInInspector] private SpawnShape initializedSpawnShape = SpawnShape.Disc;
    [Header("Initial Distribution")]
    [SerializeField] private Vector2 spawnCenter = new Vector2(0.5f, 0.5f);
    [Range(0.01f, 1f)] [SerializeField] private float spawnRadius = 0.82f;
    [Range(0.001f, 0.5f)] [SerializeField] private float spawnThickness = 0.08f;

    [Header("Trail-dependent Behaviour (distances are pixels, angles are degrees)")]
    [SerializeField] private SignalCurve sensorDistance = new SignalCurve(10f, 0f, 1f);
    [SerializeField] private SignalCurve sensorAngle = new SignalCurve(42f, 0f, 1f);
    [SerializeField] private SignalCurve rotationAngle = new SignalCurve(28f, 0f, 1f);
    [SerializeField] private SignalCurve moveDistance = new SignalCurve(1.25f, 0f, 1f);

    [Header("Sensing")]
    [Tooltip("Samples the response-driving trail this many pixels ahead of each agent.")]
    [SerializeField] private float responseProbeForwardOffset;
    [Tooltip("World-up pixel offset for the response-driving trail sample.")]
    [SerializeField] private float responseProbeVerticalOffset;
    [Min(0f)] [SerializeField] private float sensedValueScale = 0.7f;
    [SerializeField] private bool bilinearSensing = true;
    [Range(0f, 30f)] [SerializeField] private float turnNoiseDegrees = 1.5f;
    [Range(0f, 0.02f)] [SerializeField] private float respawnChance;

    [Header("Trail")]
    [Range(0f, 1f)] [SerializeField] private float diffusion = 0.9f;
    [Range(0.8f, 0.9999f)] [SerializeField] private float decay = 0.965f;
    [Min(0f)] [SerializeField] private float depositStrength = 0.28f;
    [Range(1, 256)] [SerializeField] private int depositCountLimit = 64;
    [Min(0.01f)] [SerializeField] private float trailValueLimit = 12f;

    [Header("Appearance")]
    [SerializeField] private DisplayMode displayMode = DisplayMode.TrailAndParticles;
    [SerializeField] private Color backgroundColor = new Color(0.003f, 0.005f, 0.012f, 1f);
    [SerializeField] private Color shadowColor = new Color(0.02f, 0.08f, 0.16f, 1f);
    [SerializeField] private Color midColor = new Color(0.1f, 0.85f, 0.75f, 1f);
    [SerializeField] private Color highlightColor = new Color(1f, 0.75f, 0.2f, 1f);
    [Min(0f)] [SerializeField] private float trailExposure = 0.55f;
    [Min(0f)] [SerializeField] private float particleExposure = 1.4f;
    [Range(0.1f, 3f)] [SerializeField] private float contrast = 0.75f;
    [Range(0.05f, 0.95f)] [SerializeField] private float colorSplit = 0.48f;
    [Range(0f, 1f)] [SerializeField] private float particleHighlight = 0.7f;

    private static readonly int AgentsId = Shader.PropertyToID("_Agents");
    private static readonly int TrailAId = Shader.PropertyToID("_TrailA");
    private static readonly int TrailBId = Shader.PropertyToID("_TrailB");
    private static readonly int TrailReadId = Shader.PropertyToID("_TrailRead");
    private static readonly int TrailWriteId = Shader.PropertyToID("_TrailWrite");
    private static readonly int ParticleCountersId = Shader.PropertyToID("_ParticleCounters");
    private static readonly int ParticleDensityId = Shader.PropertyToID("_ParticleDensity");
    private static readonly int ResolutionId = Shader.PropertyToID("_Resolution");
    private static readonly int AgentCountId = Shader.PropertyToID("_AgentCount");
    private static readonly int SeedId = Shader.PropertyToID("_Seed");
    private static readonly int IterationId = Shader.PropertyToID("_Iteration");
    private static readonly int SpawnShapeId = Shader.PropertyToID("_SpawnShape");
    private static readonly int SpawnCenterId = Shader.PropertyToID("_SpawnCenter");
    private static readonly int SpawnRadiusId = Shader.PropertyToID("_SpawnRadius");
    private static readonly int SpawnThicknessId = Shader.PropertyToID("_SpawnThickness");
    private static readonly int SensorDistanceCurveId = Shader.PropertyToID("_SensorDistanceCurve");
    private static readonly int SensorAngleCurveId = Shader.PropertyToID("_SensorAngleCurve");
    private static readonly int RotationAngleCurveId = Shader.PropertyToID("_RotationAngleCurve");
    private static readonly int MoveDistanceCurveId = Shader.PropertyToID("_MoveDistanceCurve");
    private static readonly int ResponseProbeForwardOffsetId = Shader.PropertyToID("_ResponseProbeForwardOffset");
    private static readonly int ResponseProbeVerticalOffsetId = Shader.PropertyToID("_ResponseProbeVerticalOffset");
    private static readonly int SensedValueScaleId = Shader.PropertyToID("_SensedValueScale");
    private static readonly int BilinearSensingId = Shader.PropertyToID("_BilinearSensing");
    private static readonly int TurnNoiseId = Shader.PropertyToID("_TurnNoise");
    private static readonly int RespawnChanceId = Shader.PropertyToID("_RespawnChance");
    private static readonly int FieldMapId = Shader.PropertyToID("_FieldMap");
    private static readonly int HasFieldMapId = Shader.PropertyToID("_HasFieldMap");
    private static readonly int FieldModeId = Shader.PropertyToID("_FieldMode");
    private static readonly int FieldStrengthId = Shader.PropertyToID("_FieldStrength");
    private static readonly int FieldGradientDistanceId = Shader.PropertyToID("_FieldGradientDistance");
    private static readonly int FieldMaxTurnId = Shader.PropertyToID("_FieldMaxTurn");
    private static readonly int FieldContrastId = Shader.PropertyToID("_FieldContrast");
    private static readonly int FieldSpeedInfluenceId = Shader.PropertyToID("_FieldSpeedInfluence");
    private static readonly int FlipFieldYId = Shader.PropertyToID("_FlipFieldY");
    private static readonly int DiffusionId = Shader.PropertyToID("_Diffusion");
    private static readonly int DecayId = Shader.PropertyToID("_Decay");
    private static readonly int DepositStrengthId = Shader.PropertyToID("_DepositStrength");
    private static readonly int DepositCountLimitId = Shader.PropertyToID("_DepositCountLimit");
    private static readonly int TrailValueLimitId = Shader.PropertyToID("_TrailValueLimit");
    private static readonly int TrailTextureId = Shader.PropertyToID("_TrailTexture");
    private static readonly int ParticleTextureId = Shader.PropertyToID("_ParticleTexture");
    private static readonly int DisplayModeId = Shader.PropertyToID("_DisplayMode");
    private static readonly int BackgroundColorId = Shader.PropertyToID("_BackgroundColor");
    private static readonly int ShadowColorId = Shader.PropertyToID("_ShadowColor");
    private static readonly int MidColorId = Shader.PropertyToID("_MidColor");
    private static readonly int HighlightColorId = Shader.PropertyToID("_HighlightColor");
    private static readonly int TrailExposureId = Shader.PropertyToID("_TrailExposure");
    private static readonly int ParticleExposureId = Shader.PropertyToID("_ParticleExposure");
    private static readonly int ContrastId = Shader.PropertyToID("_Contrast");
    private static readonly int ColorSplitId = Shader.PropertyToID("_ColorSplit");
    private static readonly int ParticleHighlightId = Shader.PropertyToID("_ParticleHighlight");

    private const int AgentThreadGroupSize = 256;
    private const int TextureThreadGroupSize = 8;
    private const int AgentStride = 16;

    private ComputeBuffer agentBuffer;
    private RenderTexture trailRead;
    private RenderTexture trailWrite;
    private RenderTexture particleCounters;
    private RenderTexture particleDensity;
    private Material runtimeMaterial;
    private Material originalMaterial;
    private Mesh generatedQuad;
    private MeshRenderer meshRenderer;
    private RenderTexture ownedSourceCameraTexture;
    private Camera configuredSourceCamera;
    private RenderTexture originalSourceCameraTarget;

    private int initializeAgentsKernel;
    private int clearSimulationKernel;
    private int clearCountersKernel;
    private int moveAgentsKernel;
    private int updateTrailKernel;
    private int allocatedAgentCount;
    private Vector2Int allocatedResolution;
    private uint iteration;
    private bool initialized;
    private bool needsReset = true;
    private bool reportedUnsupported;

    public RenderTexture TrailTexture => trailRead;
    public RenderTexture ParticleTexture => particleDensity;
    public bool IsPaused => paused;
    public Pattern SelectedPattern => selectedPattern;

    public PhysarumSimulationParam Param
    {
        get => new PhysarumSimulationParam
        {
            selectedPattern = (PhysarumSimulationParam.Pattern)selectedPattern,
            resolution = resolution,
            agentCount = agentCount,
            iterationsPerFrame = iterationsPerFrame,
            seed = seed,
            paused = paused,
            spawnShape = (PhysarumSimulationParam.SpawnShape)spawnShape,
            spawnCenter = spawnCenter,
            spawnRadius = spawnRadius,
            spawnThickness = spawnThickness,
            sensorDistance = ToParam(sensorDistance),
            sensorAngle = ToParam(sensorAngle),
            rotationAngle = ToParam(rotationAngle),
            moveDistance = ToParam(moveDistance),
            responseProbeForwardOffset = responseProbeForwardOffset,
            responseProbeVerticalOffset = responseProbeVerticalOffset,
            sensedValueScale = sensedValueScale,
            bilinearSensing = bilinearSensing,
            turnNoiseDegrees = turnNoiseDegrees,
            respawnChance = respawnChance,
            diffusion = diffusion,
            decay = decay,
            depositStrength = depositStrength,
            depositCountLimit = depositCountLimit,
            trailValueLimit = trailValueLimit,
            displayMode = (PhysarumSimulationParam.DisplayMode)displayMode,
            backgroundColor = backgroundColor,
            shadowColor = shadowColor,
            midColor = midColor,
            highlightColor = highlightColor,
            trailExposure = trailExposure,
            particleExposure = particleExposure,
            contrast = contrast,
            colorSplit = colorSplit,
            particleHighlight = particleHighlight,
            fieldMode = (PhysarumSimulationParam.FieldMode)fieldMode,
            fieldStrength = fieldStrength,
            fieldGradientDistance = fieldGradientDistance,
            fieldMaxTurnDegrees = fieldMaxTurnDegrees,
            fieldContrast = fieldContrast,
            fieldSpeedInfluence = fieldSpeedInfluence,
            flipFieldY = flipFieldY
        };
        set => ApplyParam(value);
    }

    private void ApplyParam(PhysarumSimulationParam value)
    {
        if (value == null)
            return;

        selectedPattern = (Pattern)value.selectedPattern;
        resolution = value.resolution;
        agentCount = value.agentCount;
        iterationsPerFrame = value.iterationsPerFrame;
        seed = value.seed;
        paused = value.paused;
        spawnShape = (SpawnShape)value.spawnShape;
        spawnCenter = value.spawnCenter;
        spawnRadius = value.spawnRadius;
        spawnThickness = value.spawnThickness;
        sensorDistance = FromParam(value.sensorDistance);
        sensorAngle = FromParam(value.sensorAngle);
        rotationAngle = FromParam(value.rotationAngle);
        moveDistance = FromParam(value.moveDistance);
        responseProbeForwardOffset = value.responseProbeForwardOffset;
        responseProbeVerticalOffset = value.responseProbeVerticalOffset;
        sensedValueScale = value.sensedValueScale;
        bilinearSensing = value.bilinearSensing;
        turnNoiseDegrees = value.turnNoiseDegrees;
        respawnChance = value.respawnChance;
        diffusion = value.diffusion;
        decay = value.decay;
        depositStrength = value.depositStrength;
        depositCountLimit = value.depositCountLimit;
        trailValueLimit = value.trailValueLimit;
        displayMode = (DisplayMode)value.displayMode;
        backgroundColor = value.backgroundColor;
        shadowColor = value.shadowColor;
        midColor = value.midColor;
        highlightColor = value.highlightColor;
        trailExposure = value.trailExposure;
        particleExposure = value.particleExposure;
        contrast = value.contrast;
        colorSplit = value.colorSplit;
        particleHighlight = value.particleHighlight;
        fieldMode = (FieldMode)value.fieldMode;
        fieldStrength = value.fieldStrength;
        fieldGradientDistance = value.fieldGradientDistance;
        fieldMaxTurnDegrees = value.fieldMaxTurnDegrees;
        fieldContrast = value.fieldContrast;
        fieldSpeedInfluence = value.fieldSpeedInfluence;
        flipFieldY = value.flipFieldY;

        OnValidate();
    }

    private static PhysarumSimulationParam.SignalCurve ToParam(SignalCurve value)
    {
        return new PhysarumSimulationParam.SignalCurve(value.constant, value.response, value.exponent);
    }

    private static SignalCurve FromParam(PhysarumSimulationParam.SignalCurve value)
    {
        return new SignalCurve(value.constant, value.response, value.exponent);
    }

    private void Reset()
    {
        LoadAutomaticAssets();
        ApplySelectedPreset();
        EnsureQuadMesh();
    }

    private void OnEnable()
    {
        LoadAutomaticAssets();
        EnsureQuadMesh();
        ConfigureRenderer();

        if (Application.isPlaying)
            ResetSimulation();
    }

    private void Update()
    {
        if (!Application.isPlaying)
            return;

        if (!EnsureResources())
            return;

        if (needsReset)
            ResetSimulation();

        if (!paused)
        {
            for (int i = 0; i < iterationsPerFrame; i++)
                SimulateIteration();
        }

        UpdateDisplayMaterial();
    }

    private void OnDisable()
    {
        ReleaseResources();
        ReleaseOwnedSourceCameraTexture();
        ReleaseRendererResources();
    }

    private void OnDestroy()
    {
        ReleaseResources();
        ReleaseOwnedSourceCameraTexture();
        ReleaseRendererResources();

        if (generatedQuad != null)
            CoreUtils.Destroy(generatedQuad);
    }

    private void OnValidate()
    {
        resolution.x = Mathf.Clamp(resolution.x, 64, 4096);
        resolution.y = Mathf.Clamp(resolution.y, 64, 4096);
        agentCount = Mathf.Clamp(agentCount, 1024, AgentThreadGroupSize * 65535);
        iterationsPerFrame = Mathf.Clamp(iterationsPerFrame, 1, 8);
        sensorDistance.exponent = Mathf.Max(0.01f, sensorDistance.exponent);
        sensorAngle.exponent = Mathf.Max(0.01f, sensorAngle.exponent);
        rotationAngle.exponent = Mathf.Max(0.01f, rotationAngle.exponent);
        moveDistance.exponent = Mathf.Max(0.01f, moveDistance.exponent);
        trailValueLimit = Mathf.Max(0.01f, trailValueLimit);
        depositCountLimit = Mathf.Max(1, depositCountLimit);
        fieldStrength = Mathf.Max(0f, fieldStrength);
        fieldGradientDistance = Mathf.Max(0.5f, fieldGradientDistance);
        fieldMaxTurnDegrees = Mathf.Clamp(fieldMaxTurnDegrees, 0f, 180f);
        fieldContrast = Mathf.Max(0.1f, fieldContrast);
        fieldSpeedInfluence = Mathf.Clamp(fieldSpeedInfluence, -1f, 1f);

        if (Application.isPlaying && initialized &&
            (allocatedAgentCount != agentCount || allocatedResolution != resolution))
        {
            ReleaseResources();
        }

        // Inspector enum changes should be direct manipulation: choosing a
        // pattern applies its parameter set, and choosing a spawn shape marks
        // the agent state for initialization on the next simulation frame.
        if (selectedPattern != appliedPattern)
        {
            ApplyPreset(selectedPattern);
            return;
        }

        if (spawnShape != initializedSpawnShape)
        {
            initializedSpawnShape = spawnShape;
            needsReset = true;
        }
    }

    private Texture ResolveSource()
    {
        if (sourceTexture)
        {
            ReleaseOwnedSourceCameraTexture();
            return sourceTexture;
        }

        if (!sourceCamera)
        {
            ReleaseOwnedSourceCameraTexture();
            return null;
        }

        if (sourceCamera.targetTexture != null && sourceCamera.targetTexture != ownedSourceCameraTexture)
        {
            ReleaseOwnedSourceCameraTexture();
            return sourceCamera.targetTexture;
        }

        bool needsCameraTexture = ownedSourceCameraTexture == null
            || configuredSourceCamera != sourceCamera
            || ownedSourceCameraTexture.width != resolution.x
            || ownedSourceCameraTexture.height != resolution.y;

        if (needsCameraTexture)
        {
            ReleaseOwnedSourceCameraTexture();
            configuredSourceCamera = sourceCamera;
            originalSourceCameraTarget = sourceCamera.targetTexture;
            ownedSourceCameraTexture = new RenderTexture(
                resolution.x,
                resolution.y,
                24,
                RenderTextureFormat.ARGB32,
                RenderTextureReadWrite.Linear)
            {
                name = "Physarum Field Camera",
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                hideFlags = HideFlags.HideAndDontSave
            };
            ownedSourceCameraTexture.Create();
            sourceCamera.targetTexture = ownedSourceCameraTexture;
        }

        return ownedSourceCameraTexture;
    }
    
    public void ResetSimulation()
    {
        if (!EnsureResources())
            return;

        SetSharedSimulationParameters();
        simulationCompute.SetInt(SeedId, seed);
        simulationCompute.SetInt(SpawnShapeId, (int)spawnShape);
        simulationCompute.SetVector(SpawnCenterId, new Vector4(spawnCenter.x, spawnCenter.y, 0f, 0f));
        simulationCompute.SetFloat(SpawnRadiusId, spawnRadius);
        simulationCompute.SetFloat(SpawnThicknessId, spawnThickness);

        simulationCompute.SetBuffer(initializeAgentsKernel, AgentsId, agentBuffer);
        simulationCompute.Dispatch(initializeAgentsKernel, DivideRoundUp(agentCount, AgentThreadGroupSize), 1, 1);

        simulationCompute.SetTexture(clearSimulationKernel, TrailAId, trailRead);
        simulationCompute.SetTexture(clearSimulationKernel, TrailBId, trailWrite);
        simulationCompute.SetTexture(clearSimulationKernel, ParticleCountersId, particleCounters);
        simulationCompute.SetTexture(clearSimulationKernel, ParticleDensityId, particleDensity);
        simulationCompute.Dispatch(
            clearSimulationKernel,
            DivideRoundUp(resolution.x, TextureThreadGroupSize),
            DivideRoundUp(resolution.y, TextureThreadGroupSize),
            1);

        iteration = 0;
        initializedSpawnShape = spawnShape;
        needsReset = false;
        UpdateDisplayMaterial();
    }

    public void ApplySelectedPreset()
    {
        ApplyPreset(selectedPattern);
    }

    public void ApplyPreset(Pattern pattern)
    {
        selectedPattern = pattern;
        respawnChance = 0f;
        bilinearSensing = true;
        trailValueLimit = 12f;
        depositCountLimit = 64;
        displayMode = DisplayMode.TrailAndParticles;
        backgroundColor = Hex("03050C");

        switch (pattern)
        {
            case Pattern.OrganicVeins:
                spawnShape = SpawnShape.Disc;
                spawnRadius = 0.82f;
                spawnThickness = 0.08f;
                sensorDistance = new SignalCurve(10f, 0f, 1f);
                sensorAngle = new SignalCurve(42f, 0f, 1f);
                rotationAngle = new SignalCurve(28f, 0f, 1f);
                moveDistance = new SignalCurve(1.25f, 0f, 1f);
                responseProbeForwardOffset = 0f;
                responseProbeVerticalOffset = 0f;
                sensedValueScale = 0.7f;
                turnNoiseDegrees = 1.5f;
                diffusion = 0.9f;
                decay = 0.965f;
                depositStrength = 0.28f;
                shadowColor = Hex("06213B");
                midColor = Hex("1DD6B7");
                highlightColor = Hex("FFD166");
                trailExposure = 0.55f;
                particleExposure = 1.4f;
                contrast = 0.75f;
                colorSplit = 0.48f;
                particleHighlight = 0.7f;
                break;

            case Pattern.CoralGrowth:
                spawnShape = SpawnShape.Random;
                sensorDistance = new SignalCurve(5f, 18f, 1.8f);
                sensorAngle = new SignalCurve(68f, -34f, 1.1f);
                rotationAngle = new SignalCurve(18f, 46f, 2.2f);
                moveDistance = new SignalCurve(0.75f, 1.25f, 1.5f);
                responseProbeForwardOffset = 4f;
                responseProbeVerticalOffset = 0f;
                sensedValueScale = 0.42f;
                turnNoiseDegrees = 3f;
                diffusion = 0.76f;
                decay = 0.972f;
                depositStrength = 0.22f;
                shadowColor = Hex("2A0A3A");
                midColor = Hex("F04E98");
                highlightColor = Hex("FFDB8A");
                trailExposure = 0.48f;
                particleExposure = 1.2f;
                contrast = 0.68f;
                colorSplit = 0.56f;
                particleHighlight = 0.65f;
                break;

            case Pattern.NeuralMesh:
                spawnShape = SpawnShape.Random;
                sensorDistance = new SignalCurve(16f, -8f, 0.65f);
                sensorAngle = new SignalCurve(31f, 52f, 2f);
                rotationAngle = new SignalCurve(52f, -34f, 0.8f);
                moveDistance = new SignalCurve(1.65f, -0.9f, 1.4f);
                responseProbeForwardOffset = -3f;
                responseProbeVerticalOffset = 0f;
                sensedValueScale = 0.5f;
                turnNoiseDegrees = 0.8f;
                diffusion = 0.94f;
                decay = 0.956f;
                depositStrength = 0.34f;
                shadowColor = Hex("071D49");
                midColor = Hex("4FA8FF");
                highlightColor = Hex("F0F7FF");
                trailExposure = 0.62f;
                particleExposure = 1.8f;
                contrast = 0.82f;
                colorSplit = 0.42f;
                particleHighlight = 0.82f;
                break;

            case Pattern.OrbitBloom:
                spawnShape = SpawnShape.Ring;
                spawnRadius = 0.7f;
                spawnThickness = 0.025f;
                sensorDistance = new SignalCurve(8f, 26f, 1.3f);
                sensorAngle = new SignalCurve(78f, -55f, 1.6f);
                rotationAngle = new SignalCurve(15f, 72f, 1.7f);
                moveDistance = new SignalCurve(1.9f, -1.25f, 0.9f);
                responseProbeForwardOffset = 8f;
                responseProbeVerticalOffset = 7f;
                sensedValueScale = 0.33f;
                turnNoiseDegrees = 1.2f;
                diffusion = 0.86f;
                decay = 0.978f;
                depositStrength = 0.2f;
                shadowColor = Hex("1D123F");
                midColor = Hex("7B5CFF");
                highlightColor = Hex("FFEF9F");
                trailExposure = 0.7f;
                particleExposure = 1.5f;
                contrast = 0.62f;
                colorSplit = 0.52f;
                particleHighlight = 0.75f;
                break;

            case Pattern.CellularFans:
                spawnShape = SpawnShape.Disc;
                spawnThickness = 0.045f;
                sensorDistance = new SignalCurve(4f, 34f, 2.6f);
                sensorAngle = new SignalCurve(95f, -72f, 0.9f);
                rotationAngle = new SignalCurve(70f, -58f, 1.2f);
                moveDistance = new SignalCurve(0.55f, 2.1f, 2.1f);
                responseProbeForwardOffset = 2f;
                responseProbeVerticalOffset = -11f;
                sensedValueScale = 0.3f;
                turnNoiseDegrees = 4f;
                respawnChance = 0.00015f;
                diffusion = 0.7f;
                decay = 0.982f;
                depositStrength = 0.18f;
                shadowColor = Hex("10291F");
                midColor = Hex("75E06D");
                highlightColor = Hex("F8FFB0");
                trailExposure = 0.58f;
                particleExposure = 1.35f;
                contrast = 0.72f;
                colorSplit = 0.6f;
                particleHighlight = 0.62f;
                break;
        }

        appliedPattern = selectedPattern;
        initializedSpawnShape = spawnShape;
        needsReset = true;
    }

    public void SetPaused(bool value) => paused = value;
    public void TogglePaused() => paused = !paused;

    private bool EnsureResources()
    {
        LoadAutomaticAssets();

        if (!SystemInfo.supportsComputeShaders || simulationCompute == null || displayShader == null)
        {
            if (!reportedUnsupported)
            {
                Debug.LogError(
                    $"{nameof(PhysarumSimulation)} requires compute shader support and its Physarum assets.",
                    this);
                reportedUnsupported = true;
            }

            return false;
        }

        reportedUnsupported = false;
        ConfigureRenderer();

        if (initialized && allocatedAgentCount == agentCount && allocatedResolution == resolution)
            return true;

        ReleaseResources();
        FindKernels();

        agentBuffer = new ComputeBuffer(agentCount, AgentStride, ComputeBufferType.Structured);
        trailRead = CreateRenderTexture("Physarum Trail A", GraphicsFormat.R32_SFloat, FilterMode.Bilinear);
        trailWrite = CreateRenderTexture("Physarum Trail B", GraphicsFormat.R32_SFloat, FilterMode.Bilinear);
        particleCounters = CreateRenderTexture("Physarum Particle Counters", GraphicsFormat.R32_UInt, FilterMode.Point);
        particleDensity = CreateRenderTexture("Physarum Particle Density", GraphicsFormat.R32_SFloat, FilterMode.Bilinear);

        allocatedAgentCount = agentCount;
        allocatedResolution = resolution;
        initialized = true;
        return true;
    }

    private void SimulateIteration()
    {
        SetSharedSimulationParameters();
        simulationCompute.SetInt(IterationId, unchecked((int)iteration));

        simulationCompute.SetTexture(clearCountersKernel, ParticleCountersId, particleCounters);
        simulationCompute.Dispatch(
            clearCountersKernel,
            DivideRoundUp(resolution.x, TextureThreadGroupSize),
            DivideRoundUp(resolution.y, TextureThreadGroupSize),
            1);

        simulationCompute.SetBuffer(moveAgentsKernel, AgentsId, agentBuffer);
        simulationCompute.SetTexture(moveAgentsKernel, TrailReadId, trailRead);
        Texture fieldMap = ResolveSource();
        simulationCompute.SetInt(HasFieldMapId, fieldMap != null ? 1 : 0);
        simulationCompute.SetTexture(moveAgentsKernel, FieldMapId, fieldMap != null ? fieldMap : Texture2D.blackTexture);
        simulationCompute.SetTexture(moveAgentsKernel, ParticleCountersId, particleCounters);
        simulationCompute.Dispatch(moveAgentsKernel, DivideRoundUp(agentCount, AgentThreadGroupSize), 1, 1);

        simulationCompute.SetTexture(updateTrailKernel, TrailReadId, trailRead);
        simulationCompute.SetTexture(updateTrailKernel, TrailWriteId, trailWrite);
        simulationCompute.SetTexture(updateTrailKernel, ParticleCountersId, particleCounters);
        simulationCompute.SetTexture(updateTrailKernel, ParticleDensityId, particleDensity);
        simulationCompute.Dispatch(
            updateTrailKernel,
            DivideRoundUp(resolution.x, TextureThreadGroupSize),
            DivideRoundUp(resolution.y, TextureThreadGroupSize),
            1);

        (trailRead, trailWrite) = (trailWrite, trailRead);
        iteration++;
    }

    private void SetSharedSimulationParameters()
    {
        simulationCompute.SetInts(ResolutionId, resolution.x, resolution.y);
        simulationCompute.SetInt(AgentCountId, agentCount);
        simulationCompute.SetInt(SeedId, seed);
        simulationCompute.SetVector(SensorDistanceCurveId, CurveVector(sensorDistance, false));
        simulationCompute.SetVector(SensorAngleCurveId, CurveVector(sensorAngle, true));
        simulationCompute.SetVector(RotationAngleCurveId, CurveVector(rotationAngle, true));
        simulationCompute.SetVector(MoveDistanceCurveId, CurveVector(moveDistance, false));
        simulationCompute.SetFloat(ResponseProbeForwardOffsetId, responseProbeForwardOffset);
        simulationCompute.SetFloat(ResponseProbeVerticalOffsetId, responseProbeVerticalOffset);
        simulationCompute.SetFloat(SensedValueScaleId, sensedValueScale);
        simulationCompute.SetInt(BilinearSensingId, bilinearSensing ? 1 : 0);
        simulationCompute.SetFloat(TurnNoiseId, turnNoiseDegrees * Mathf.Deg2Rad);
        simulationCompute.SetFloat(RespawnChanceId, respawnChance);
        simulationCompute.SetInt(FieldModeId, (int)fieldMode);
        simulationCompute.SetFloat(FieldStrengthId, fieldStrength);
        simulationCompute.SetFloat(FieldGradientDistanceId, fieldGradientDistance);
        simulationCompute.SetFloat(FieldMaxTurnId, fieldMaxTurnDegrees * Mathf.Deg2Rad);
        simulationCompute.SetFloat(FieldContrastId, fieldContrast);
        simulationCompute.SetFloat(FieldSpeedInfluenceId, fieldSpeedInfluence);
        simulationCompute.SetInt(FlipFieldYId, flipFieldY ? 1 : 0);
        simulationCompute.SetFloat(DiffusionId, diffusion);
        simulationCompute.SetFloat(DecayId, decay);
        simulationCompute.SetFloat(DepositStrengthId, depositStrength);
        simulationCompute.SetInt(DepositCountLimitId, depositCountLimit);
        simulationCompute.SetFloat(TrailValueLimitId, trailValueLimit);
        simulationCompute.SetInt(SpawnShapeId, (int)spawnShape);
        simulationCompute.SetVector(SpawnCenterId, new Vector4(spawnCenter.x, spawnCenter.y, 0f, 0f));
        simulationCompute.SetFloat(SpawnRadiusId, spawnRadius);
        simulationCompute.SetFloat(SpawnThicknessId, spawnThickness);
    }

    private void UpdateDisplayMaterial()
    {
        if (runtimeMaterial == null)
            return;

        runtimeMaterial.SetTexture(TrailTextureId, trailRead);
        runtimeMaterial.SetTexture(ParticleTextureId, particleDensity);
        runtimeMaterial.SetFloat(DisplayModeId, (float)displayMode);
        runtimeMaterial.SetColor(BackgroundColorId, backgroundColor);
        runtimeMaterial.SetColor(ShadowColorId, shadowColor);
        runtimeMaterial.SetColor(MidColorId, midColor);
        runtimeMaterial.SetColor(HighlightColorId, highlightColor);
        runtimeMaterial.SetFloat(TrailExposureId, trailExposure);
        runtimeMaterial.SetFloat(ParticleExposureId, particleExposure);
        runtimeMaterial.SetFloat(ContrastId, contrast);
        runtimeMaterial.SetFloat(ColorSplitId, colorSplit);
        runtimeMaterial.SetFloat(ParticleHighlightId, particleHighlight);
    }

    private void LoadAutomaticAssets()
    {
        if (simulationCompute == null)
            simulationCompute = Resources.Load<ComputeShader>("Physarum/PhysarumSimulation");

        if (displayShader == null)
            displayShader = Shader.Find("GraphicsPlayground/Physarum Display");
    }

    private void ConfigureRenderer()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        if (meshRenderer == null || displayShader == null)
            return;

        if (runtimeMaterial != null && runtimeMaterial.shader == displayShader)
            return;

        ReleaseRendererResources();
        originalMaterial = meshRenderer.sharedMaterial;
        runtimeMaterial = new Material(displayShader)
        {
            name = "Physarum Display (Runtime)",
            hideFlags = HideFlags.HideAndDontSave
        };
        meshRenderer.sharedMaterial = runtimeMaterial;
        UpdateDisplayMaterial();
    }

    private void EnsureQuadMesh()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        if (meshFilter == null || meshFilter.sharedMesh != null)
            return;

        generatedQuad = new Mesh
        {
            name = "Physarum Quad",
            hideFlags = HideFlags.HideAndDontSave,
            vertices = new[]
            {
                new Vector3(-0.5f, -0.5f, 0f),
                new Vector3(0.5f, -0.5f, 0f),
                new Vector3(-0.5f, 0.5f, 0f),
                new Vector3(0.5f, 0.5f, 0f)
            },
            uv = new[]
            {
                new Vector2(0f, 0f),
                new Vector2(1f, 0f),
                new Vector2(0f, 1f),
                new Vector2(1f, 1f)
            },
            triangles = new[] { 0, 2, 1, 2, 3, 1 }
        };
        generatedQuad.RecalculateBounds();
        meshFilter.sharedMesh = generatedQuad;
    }

    private RenderTexture CreateRenderTexture(string textureName, GraphicsFormat format, FilterMode filterMode)
    {
        var descriptor = new RenderTextureDescriptor(resolution.x, resolution.y)
        {
            graphicsFormat = format,
            depthStencilFormat = GraphicsFormat.None,
            dimension = TextureDimension.Tex2D,
            volumeDepth = 1,
            msaaSamples = 1,
            enableRandomWrite = true,
            useMipMap = false,
            autoGenerateMips = false,
            sRGB = false
        };

        var texture = new RenderTexture(descriptor)
        {
            name = textureName,
            filterMode = filterMode,
            wrapMode = TextureWrapMode.Repeat,
            hideFlags = HideFlags.HideAndDontSave
        };
        texture.Create();
        return texture;
    }

    private void FindKernels()
    {
        initializeAgentsKernel = simulationCompute.FindKernel("InitializeAgents");
        clearSimulationKernel = simulationCompute.FindKernel("ClearSimulation");
        clearCountersKernel = simulationCompute.FindKernel("ClearCounters");
        moveAgentsKernel = simulationCompute.FindKernel("MoveAgents");
        updateTrailKernel = simulationCompute.FindKernel("UpdateTrail");
    }

    private void ReleaseResources()
    {
        Release(ref agentBuffer);
        Release(ref trailRead);
        Release(ref trailWrite);
        Release(ref particleCounters);
        Release(ref particleDensity);
        initialized = false;
        needsReset = true;
    }

    private void ReleaseRendererResources()
    {
        if (meshRenderer != null && meshRenderer.sharedMaterial == runtimeMaterial)
            meshRenderer.sharedMaterial = originalMaterial;

        CoreUtils.Destroy(runtimeMaterial);
        runtimeMaterial = null;
        originalMaterial = null;
    }

    private void ReleaseOwnedSourceCameraTexture()
    {
        if (configuredSourceCamera != null && configuredSourceCamera.targetTexture == ownedSourceCameraTexture)
            configuredSourceCamera.targetTexture = originalSourceCameraTarget;

        if (ownedSourceCameraTexture != null)
        {
            ownedSourceCameraTexture.Release();
            CoreUtils.Destroy(ownedSourceCameraTexture);
        }

        ownedSourceCameraTexture = null;
        configuredSourceCamera = null;
        originalSourceCameraTarget = null;
    }

    private static void Release(ref ComputeBuffer buffer)
    {
        if (buffer == null)
            return;

        buffer.Release();
        buffer = null;
    }

    private static void Release(ref RenderTexture texture)
    {
        if (texture == null)
            return;

        texture.Release();
        CoreUtils.Destroy(texture);
        texture = null;
    }

    private static Vector4 CurveVector(SignalCurve curve, bool convertDegrees)
    {
        float scale = convertDegrees ? Mathf.Deg2Rad : 1f;
        return new Vector4(curve.constant * scale, curve.response * scale, Mathf.Max(curve.exponent, 0.01f), 0f);
    }

    private static int DivideRoundUp(int value, int divisor) => (value + divisor - 1) / divisor;

    private static Color Hex(string value)
    {
        return ColorUtility.TryParseHtmlString($"#{value}", out Color color) ? color : Color.white;
    }
}
