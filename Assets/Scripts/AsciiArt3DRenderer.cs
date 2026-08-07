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
    [Range(-20f, 20f)] public float randomDepthOffset = 0.5f;
}
/// <summary>
/// Draws a resolution-driven grid of cube instances using the ASCII Art Cubes shader.
/// Each cube represents one ASCII cell; the shader samples the reference image once
/// per cell and applies the same pattern/index mapping as AsciiArt.shader.
/// </summary>
[ExecuteAlways]
public sealed class AsciiArt3DRenderer : MonoBehaviour
{
    // RenderMeshInstanced uploads both objectToWorld and worldToObject for a
    // Matrix4x4 instance. Unity therefore limits this instance layout to 511
    // instances per draw, rather than the 1023 limit used by smaller layouts.
    private const int MaxInstancesPerDraw = 511;

    private static readonly int GridColumnsId = Shader.PropertyToID("_GridColumns");
    private static readonly int GridRowsId = Shader.PropertyToID("_GridRows");
    private static readonly int InstanceBaseIndexId = Shader.PropertyToID("_InstanceBaseIndex");

    [Header("Rendering")]
    [SerializeField] private Material material;
    [SerializeField] private Mesh mesh;
    [SerializeField] private Camera targetCamera;
    [SerializeField] private ShadowCastingMode shadowCasting = ShadowCastingMode.On;
    [SerializeField] private bool receiveShadows = true;
    
    [SerializeField] private AsciiArt3DParam param;

    [SerializeField] private int randomSeed = 1337;

    private MaterialPropertyBlock properties;
    private NativeArray<Matrix4x4>[] instanceBatches;
    private int columns;
    private int rows;
    private int instanceCount;
    private int instancesPerBatch;
    private int lastResolution = -1;
    private Vector2 lastGridSize;
    private float lastCellGap = -1f;
    private float lastCubeThickness = -1f;
    private float lastRandomDepthOffset = -1f;
    private int lastRandomSeed;
    private Matrix4x4 lastLocalToWorld;

    private void OnEnable()
    {
        properties ??= new MaterialPropertyBlock();

        if (mesh == null)
            mesh = Resources.GetBuiltinResource<Mesh>("Cube.fbx");

        if (material != null)
            material.enableInstancing = true;

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
        if (material == null || mesh == null)
            return;

        int safeResolution = Mathf.Max(1, param.resolution);
        Vector2 gridSize = new Vector2(Mathf.Max(0.01f, param.gridWidth), Mathf.Max(0.01f, param.gridHeight));
        Matrix4x4 localToWorld = transform.localToWorldMatrix;

        bool changed = force ||
                       safeResolution != lastResolution ||
                       !Mathf.Approximately(gridSize.x, lastGridSize.x) ||
                       !Mathf.Approximately(gridSize.y, lastGridSize.y) ||
                       !Mathf.Approximately(param.cellGap, lastCellGap) ||
                       !Mathf.Approximately(param.thickness, lastCubeThickness) ||
                       !Mathf.Approximately(param.randomDepthOffset, lastRandomDepthOffset) ||
                       randomSeed != lastRandomSeed ||
                       localToWorld != lastLocalToWorld;

        if (!changed)
            return;

        columns = safeResolution;
        float aspect = gridSize.x / gridSize.y;
        rows = Mathf.Max(1, Mathf.FloorToInt(columns / Mathf.Max(aspect, 0.0001f)));
        instanceCount = columns * rows;

        // Keep batch boundaries on row boundaries whenever one row fits in
        // Unity's RenderMeshInstanced limit. This makes each batch base index
        // a clean multiple of the grid column count.
        int rowsPerBatch = columns <= MaxInstancesPerDraw
            ? Mathf.Max(1, MaxInstancesPerDraw / columns)
            : 1;
        instancesPerBatch = columns <= MaxInstancesPerDraw
            ? rowsPerBatch * columns
            : MaxInstancesPerDraw;

        DisposeInstanceBatches();
        instanceBatches = new NativeArray<Matrix4x4>[Mathf.CeilToInt(instanceCount / (float)instancesPerBatch)];

        float cellWidth = gridSize.x / columns;
        float cellHeight = gridSize.y / rows;
        float minimumCell = Mathf.Min(cellWidth, cellHeight);
        float cubeDepth = minimumCell * Mathf.Max(param.thickness, 0.01f);
        Vector3 cubeScale = new Vector3(
            cellWidth * (1f - param.cellGap),
            cellHeight * (1f - param.cellGap),
            cubeDepth);

        for (int batchIndex = 0; batchIndex < instanceBatches.Length; batchIndex++)
        {
            int batchStart = batchIndex * instancesPerBatch;
            int batchCount = Mathf.Min(instancesPerBatch, instanceCount - batchStart);
            NativeArray<Matrix4x4> batch = new NativeArray<Matrix4x4>(
                batchCount, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);

            for (int localIndex = 0; localIndex < batchCount; localIndex++)
            {
                int globalIndex = batchStart + localIndex;
                int x = globalIndex % columns;
                int y = globalIndex / columns;

                float localX = -gridSize.x * 0.5f + (x + 0.5f) * cellWidth;
                float localY = -gridSize.y * 0.5f + (y + 0.5f) * cellHeight;
                float randomZ = (Hash01(globalIndex, randomSeed) * 2f - 1f) * minimumCell * param.randomDepthOffset;

                Matrix4x4 localMatrix = Matrix4x4.TRS(
                    new Vector3(localX, localY, randomZ),
                    Quaternion.identity,
                    cubeScale);
                batch[localIndex] = localToWorld * localMatrix;
            }

            instanceBatches[batchIndex] = batch;
        }

        lastResolution = safeResolution;
        lastGridSize = gridSize;
        lastCellGap = param.cellGap;
        lastCubeThickness = param.thickness;
        lastRandomDepthOffset = param.randomDepthOffset;
        lastRandomSeed = randomSeed;
        lastLocalToWorld = localToWorld;
    }

    private void DrawInstances()
    {
        if (!material || !mesh || instanceBatches == null)
            return;

        properties.Clear();
        properties.SetFloat(GridColumnsId, columns);
        properties.SetFloat(GridRowsId, rows);

        Bounds worldBounds = CalculateWorldBounds();

        for (int batchIndex = 0; batchIndex < instanceBatches.Length; batchIndex++)
        {
            int batchStart = batchIndex * instancesPerBatch;
            properties.SetFloat(InstanceBaseIndexId, batchStart);

            RenderParams renderParams = new RenderParams(material)
            {
                camera = targetCamera,
                layer = gameObject.layer,
                worldBounds = worldBounds,
                matProps = properties,
                shadowCastingMode = shadowCasting,
                receiveShadows = receiveShadows
            };

            Graphics.RenderMeshInstanced(
                renderParams,
                mesh,
                0,
                instanceBatches[batchIndex]);
        }
    }

    private Bounds CalculateWorldBounds()
    {
        Vector3 localMin = new Vector3(-lastGridSize.x * 0.5f, -lastGridSize.y * 0.5f, -lastGridSize.x);
        Vector3 localMax = new Vector3(lastGridSize.x * 0.5f, lastGridSize.y * 0.5f, lastGridSize.x);
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
        if (instanceBatches == null)
            return;

        foreach (NativeArray<Matrix4x4> batch in instanceBatches)
        {
            if (batch.IsCreated)
                batch.Dispose();
        }

        instanceBatches = null;
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
