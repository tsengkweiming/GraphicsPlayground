using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

[System.Serializable]
public class AsciiArt3DParam
{
    [Header("Grid")]
    [Min(1)] public int resolution = 60;
    [Min(0.01f)] public float gridWidth = 10f;
    [Min(0.01f)] public float gridHeight = 5.625f;
    [Range(0f, 0.9f)] public float cellGap = 0.06f;

    [Header("Object Depth")]
    [Range(0.01f, 1f)] public float thickness = 0.2f;
    [Range(-50f, 50f)] public float randomDepthOffset = 0.5f;

    [Header("Depth Motion")]
    [Min(0f)] public float depthMotionAmplitude = 0f;
    [Min(0f)] public float depthMotionSpeed = 1f;
    
    public Texture2D[] textures;
    public string textureBindName;
}
/// <summary>
/// Draws a resolution-driven grid of cube instances using the ASCII Art Cubes shader.
/// Each cube represents one ASCII cell; the shader samples the reference image once
/// per cell and applies the same pattern/index mapping as AsciiArt.shader.
/// </summary>
[ExecuteAlways]
public sealed class AsciiArt3DRenderer : ShaderController
{
    // RenderMeshInstanced uploads both objectToWorld and worldToObject for a
    // Matrix4x4 instance. Unity therefore limits this instance layout to 511
    // instances per draw, rather than the 1023 limit used by smaller layouts.
    private const int MaxInstancesPerDraw = 511;

    private static readonly int GridColumnsId = Shader.PropertyToID("_GridColumns");
    private static readonly int GridRowsId = Shader.PropertyToID("_GridRows");
    private static readonly int InstanceBaseIndexId = Shader.PropertyToID("_InstanceBaseIndex");
    private static readonly int DepthMotionAmplitudeId = Shader.PropertyToID("_DepthMotionAmplitude");
    private static readonly int DepthMotionSpeedId = Shader.PropertyToID("_DepthMotionSpeed");

    [Header("Rendering")]
    [SerializeField] private Mesh mesh;
    [SerializeField] private Camera targetCamera;
    [SerializeField] private ShadowCastingMode shadowCasting = ShadowCastingMode.On;
    [SerializeField] private bool receiveShadows = true;
    
    [SerializeField] private AsciiArt3DParam param;

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

        if (mesh == null)
            mesh = Resources.GetBuiltinResource<Mesh>("Cube.fbx");

        RebuildIfNeeded(true);
    }

    private void OnDisable()
    {
        DisposeInstanceBatches();
    }

    private void OnDestroy()
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
        if (_material == null || mesh == null)
            return;

        int safeResolution = Mathf.Max(1, param.resolution);
        Vector2 gridSize = new Vector2(Mathf.Max(0.01f, param.gridWidth), Mathf.Max(0.01f, param.gridHeight));
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

        // Keep batch boundaries on row boundaries whenever one row fits in
        // Unity's RenderMeshInstanced limit. This makes each batch base index
        // a clean multiple of the grid column count.
        int rowsPerBatch = _columns <= MaxInstancesPerDraw
            ? Mathf.Max(1, MaxInstancesPerDraw / _columns)
            : 1;
        _instancesPerBatch = _columns <= MaxInstancesPerDraw
            ? rowsPerBatch * _columns
            : MaxInstancesPerDraw;

        DisposeInstanceBatches();
        _instanceBatches = new NativeArray<Matrix4x4>[Mathf.CeilToInt(_instanceCount / (float)_instancesPerBatch)];

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
                batchCount, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);

            for (int localIndex = 0; localIndex < batchCount; localIndex++)
            {
                int globalIndex = batchStart + localIndex;
                int x = globalIndex % _columns;
                int y = globalIndex / _columns;

                float localX = -gridSize.x * 0.5f + (x + 0.5f) * cellWidth;
                float localY = -gridSize.y * 0.5f + (y + 0.5f) * cellHeight;
                float randomZ = (Hash01(globalIndex, randomSeed) * 2f - 1f) * minimumCell * param.randomDepthOffset;

                Matrix4x4 localMatrix = Matrix4x4.TRS(
                    new Vector3(localX, localY, randomZ),
                    Quaternion.identity,
                    cubeScale);
                batch[localIndex] = localToWorld * localMatrix;
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
        if (!_material || !mesh || _instanceBatches == null)
            return;

        _properties.Clear();
        _properties.SetFloat(GridColumnsId, _columns);
        _properties.SetFloat(GridRowsId, _rows);
        _properties.SetFloat(DepthMotionAmplitudeId, Mathf.Max(0f, param.depthMotionAmplitude));
        _properties.SetFloat(DepthMotionSpeedId, Mathf.Max(0f, param.depthMotionSpeed));

        for (var i = 0; i < param.textures.Length; i++)
        {
            var texName = $"{param.textureBindName}{i}";
            _properties.SetTexture(texName, param.textures[i]);
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

        for (int x = 0; x <= 1; x++)
        for (int y = 0; y <= 1; y++)
        for (int z = 0; z <= 1; z++)
        {
            Vector3 corner = new Vector3(
                x == 0 ? localMin.x : localMax.x,
                y == 0 ? localMin.y : localMax.y,
                z == 0 ? localMin.z : localMax.z);
            bounds.Encapsulate(transform.TransformPoint(corner));
        }

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
            return hash / 4294967295f;
        }
    }
}
