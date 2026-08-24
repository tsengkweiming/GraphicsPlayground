using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Adaptive 3D ASCII renderer. It keeps a fine GPU instance grid as the
/// sampling domain, while the shader collapses those instances into one cube
/// per brightness-driven quadtree leaf.
/// </summary>
[ExecuteAlways]
public sealed class AsciiArtQuadtree3DRenderer : ShaderController
{
    [System.Serializable]
    public class Parameters
    {
        [Header("Grid")]
        [Min(1)] public int resolution = 60;
        [Min(0.01f)] public float gridWidth = 10f;
        [Min(0.01f)] public float gridHeight = 5.625f;
        [Range(0f, 0.9f)] public float cellGap = 0.06f;
        public Color lineColor = Color.black;
        public float lineWidth = 1.0f;
        public float lineStrength = 1.0f;

        [Header("Adaptive Quadtree")]
        [Min(1)] public float minimumShortAxisDivisions = 4;
        [Range(1, 8)] public float maximumDepth = 6;
        [Range(0f, 1f)] public float brightnessStop = 0.5f;

        [Header("Object Depth")]
        [Min(0.01f)] public float thickness = 0.2f;
        [Range(-50f, 50f)] public float randomDepthOffset = 0.5f;

        [Header("Geometry Motion")]
        [Range(0f, 1f)] public float motionActiveThreshold;
        [Min(0f)] public float depthMotionAmplitude;
        [Min(0f)] public float depthMotionSpeed = 1f;
        [Range(-180f, 180f)] public float rotationAmplitude;

        [Header("Patterns")]
        public Texture2D[] textures;
        public string textureBindName = "_Pattern";
    }

    private const int MaxInstancesPerDraw = 511;

    private static readonly int GridColumnsId = Shader.PropertyToID("_GridColumns");
    private static readonly int GridRowsId = Shader.PropertyToID("_GridRows");
    private static readonly int GridAspectId = Shader.PropertyToID("_GridAspect");
    private static readonly int InstanceBaseIndexId = Shader.PropertyToID("_InstanceBaseIndex");
    private static readonly int MotionActiveThresholdId = Shader.PropertyToID("_MotionActiveThreshold");
    private static readonly int DepthMotionAmplitudeId = Shader.PropertyToID("_DepthMotionAmplitude");
    private static readonly int DepthMotionSpeedId = Shader.PropertyToID("_DepthMotionSpeed");
    private static readonly int RotationAmplitudeId = Shader.PropertyToID("_RotationAmplitude");
    private static readonly int QuadTreeMinDivisionsId = Shader.PropertyToID("_QuadTreeMinDivisions");
    private static readonly int QuadTreeMaxIterationsId = Shader.PropertyToID("_QuadTreeMaxIterations");
    private static readonly int QuadTreeThresholdId = Shader.PropertyToID("_QuadTreeThreshold");
    private static readonly int LineColorId = Shader.PropertyToID("_LineColor");
    private static readonly int LineWidthId = Shader.PropertyToID("_LineWidth");
    private static readonly int LineStrengthId = Shader.PropertyToID("_LineStrength");

    [SerializeField] private Mesh mesh;
    [SerializeField] private Camera targetCamera;
    [SerializeField] private ShadowCastingMode shadowCasting = ShadowCastingMode.On;
    [SerializeField] private bool receiveShadows = true;
    [SerializeField] private Parameters param = new();
    [SerializeField] private int randomSeed = 1337;

    private MaterialPropertyBlock _properties;
    private NativeArray<Matrix4x4>[] _instanceBatches;
    private int _columns;
    private int _rows;
    private int _instanceCount;
    private int _instancesPerBatch;
    private int _lastResolution = -1;
    private Vector2 _lastGridSize;
    private float _lastCellGap = -1f;
    private float _lastCubeThickness = -1f;
    private float _lastRandomDepthOffset = -1f;
    private int _lastRandomSeed;
    private Matrix4x4 _lastLocalToWorld;

    private void OnEnable()
    {
        _properties ??= new MaterialPropertyBlock();

        if (_material != null)
            _material.enableInstancing = true;

        mesh ??= Resources.GetBuiltinResource<Mesh>("Cube.fbx");
        RebuildIfNeeded(true);
    }

    private void OnDisable()
    {
        DisposeInstanceBatches();
    }

    private void LateUpdate()
    {
        RebuildIfNeeded(false);
        DrawInstances();
    }

    private void RebuildIfNeeded(bool force)
    {
        if (_material == null || mesh == null || param == null)
            return;

        int safeResolution = Mathf.Max(1, param.resolution);
        Vector2 gridSize = new Vector2(
            Mathf.Max(0.01f, param.gridWidth),
            Mathf.Max(0.01f, param.gridHeight));
        Matrix4x4 localToWorld = transform.localToWorldMatrix;

        bool changed = force ||
                       safeResolution != _lastResolution ||
                       !Mathf.Approximately(gridSize.x, _lastGridSize.x) ||
                       !Mathf.Approximately(gridSize.y, _lastGridSize.y) ||
                       !Mathf.Approximately(param.cellGap, _lastCellGap) ||
                       !Mathf.Approximately(param.thickness, _lastCubeThickness) ||
                       !Mathf.Approximately(param.randomDepthOffset, _lastRandomDepthOffset) ||
                       randomSeed != _lastRandomSeed ||
                       localToWorld != _lastLocalToWorld;

        if (!changed)
            return;

        _columns = safeResolution;
        float aspect = gridSize.x / gridSize.y;
        _rows = Mathf.Max(1, Mathf.FloorToInt(_columns / Mathf.Max(aspect, 0.0001f)));
        _instanceCount = _columns * _rows;

        int rowsPerBatch = _columns <= MaxInstancesPerDraw
            ? Mathf.Max(1, MaxInstancesPerDraw / _columns)
            : 1;
        _instancesPerBatch = _columns <= MaxInstancesPerDraw
            ? rowsPerBatch * _columns
            : MaxInstancesPerDraw;

        DisposeInstanceBatches();
        _instanceBatches = new NativeArray<Matrix4x4>[
            Mathf.CeilToInt(_instanceCount / (float)_instancesPerBatch)];

        float cellWidth = gridSize.x / _columns;
        float cellHeight = gridSize.y / _rows;
        float minimumCell = Mathf.Min(cellWidth, cellHeight);
        float cubeDepth = minimumCell * Mathf.Max(param.thickness, 0.01f);
        Vector3 cubeScale = new Vector3(
            cellWidth * (1f - param.cellGap),
            cellHeight * (1f - param.cellGap),
            cubeDepth);

        for (int batchIndex = 0; batchIndex < _instanceBatches.Length; batchIndex++)
        {
            int batchStart = batchIndex * _instancesPerBatch;
            int batchCount = Mathf.Min(_instancesPerBatch, _instanceCount - batchStart);
            NativeArray<Matrix4x4> batch = new NativeArray<Matrix4x4>(
                batchCount,
                Allocator.Persistent,
                NativeArrayOptions.UninitializedMemory);

            for (int localIndex = 0; localIndex < batchCount; localIndex++)
            {
                int globalIndex = batchStart + localIndex;
                int x = globalIndex % _columns;
                int y = globalIndex / _columns;

                float localX = -gridSize.x * 0.5f + (x + 0.5f) * cellWidth;
                float localY = -gridSize.y * 0.5f + (y + 0.5f) * cellHeight;
                float randomZ = (Hash01(globalIndex, randomSeed) * 2f - 1f) *
                                minimumCell * param.randomDepthOffset;

                batch[localIndex] = localToWorld * Matrix4x4.TRS(
                    new Vector3(localX, localY, randomZ),
                    Quaternion.identity,
                    cubeScale);
            }

            _instanceBatches[batchIndex] = batch;
        }

        _lastResolution = safeResolution;
        _lastGridSize = gridSize;
        _lastCellGap = param.cellGap;
        _lastCubeThickness = param.thickness;
        _lastRandomDepthOffset = param.randomDepthOffset;
        _lastRandomSeed = randomSeed;
        _lastLocalToWorld = localToWorld;
    }

    private void DrawInstances()
    {
        if (!_material || !mesh || _instanceBatches == null || param == null)
            return;

        _properties.Clear();
        _properties.SetFloat(GridColumnsId, _columns);
        _properties.SetFloat(GridRowsId, _rows);
        _properties.SetFloat(GridAspectId, param.gridWidth / Mathf.Max(param.gridHeight, 0.0001f));
        _properties.SetFloat(QuadTreeMinDivisionsId, Mathf.Max(1, param.minimumShortAxisDivisions));
        _properties.SetFloat(QuadTreeMaxIterationsId, Mathf.Clamp(param.maximumDepth, 1, 8));
        _properties.SetFloat(QuadTreeThresholdId, Mathf.Clamp01(param.brightnessStop));
        _properties.SetFloat(MotionActiveThresholdId, param.motionActiveThreshold);
        _properties.SetFloat(DepthMotionAmplitudeId, Mathf.Max(0f, param.depthMotionAmplitude));
        _properties.SetFloat(DepthMotionSpeedId, Mathf.Max(0f, param.depthMotionSpeed));
        _properties.SetFloat(RotationAmplitudeId, param.rotationAmplitude * Mathf.Deg2Rad);
        _properties.SetFloat(LineWidthId, param.lineWidth);
        _properties.SetFloat(LineStrengthId, param.lineStrength);
        _properties.SetColor(LineColorId, param.lineColor);

        if (param.textures != null)
        {
            for (int i = 0; i < param.textures.Length; i++)
            {
                if (param.textures[i])
                    _properties.SetTexture($"{param.textureBindName}{i}", param.textures[i]);
            }
        }

        Bounds worldBounds = CalculateWorldBounds();
        for (int batchIndex = 0; batchIndex < _instanceBatches.Length; batchIndex++)
        {
            int batchStart = batchIndex * _instancesPerBatch;
            _properties.SetFloat(InstanceBaseIndexId, batchStart);

            RenderParams renderParams = new RenderParams(_material)
            {
                camera = targetCamera,
                layer = gameObject.layer,
                worldBounds = worldBounds,
                matProps = _properties,
                shadowCastingMode = shadowCasting,
                receiveShadows = receiveShadows
            };

            Graphics.RenderMeshInstanced(
                renderParams,
                mesh,
                0,
                _instanceBatches[batchIndex]);
        }
    }

    private Bounds CalculateWorldBounds()
    {
        Vector3 localMin = new Vector3(-_lastGridSize.x * 0.5f, -_lastGridSize.y * 0.5f, -_lastGridSize.x);
        Vector3 localMax = new Vector3(_lastGridSize.x * 0.5f, _lastGridSize.y * 0.5f, _lastGridSize.x);
        Bounds bounds = new Bounds(transform.TransformPoint(localMin), Vector3.zero);

        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMin.x, localMin.y, localMax.z)));
        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMin.x, localMax.y, localMin.z)));
        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMin.x, localMax.y, localMax.z)));
        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMax.x, localMin.y, localMin.z)));
        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMax.x, localMin.y, localMax.z)));
        bounds.Encapsulate(transform.TransformPoint(new Vector3(localMax.x, localMax.y, localMin.z)));
        bounds.Encapsulate(transform.TransformPoint(localMax));
        return bounds;
    }

    private void DisposeInstanceBatches()
    {
        if (_instanceBatches == null)
            return;

        foreach (NativeArray<Matrix4x4> batch in _instanceBatches)
        {
            if (batch.IsCreated)
                batch.Dispose();
        }

        _instanceBatches = null;
    }

    private static float Hash01(int value, int seed)
    {
        unchecked
        {
            uint hash = (uint)(value + 1) ^ (uint)seed;
            hash ^= hash >> 16;
            hash *= 0x7feb352du;
            hash ^= hash >> 15;
            hash *= 0x846ca68bu;
            hash ^= hash >> 16;
            return (hash & 0x00ffffffu) / 16777215f;
        }
    }
}
