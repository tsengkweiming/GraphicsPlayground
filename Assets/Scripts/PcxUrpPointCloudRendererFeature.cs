using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Draws all active PcxUrpPointCloudRenderer components through the URP pass
/// system instead of relying on MonoBehaviour.OnRenderObject.
/// </summary>
[DisallowMultipleRendererFeature]
public sealed class PcxUrpPointCloudRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private Shader _shader;
    [SerializeField] private RenderPassEvent _renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    [SerializeField] private LayerMask _layerMask = ~0;

    private PcxUrpPointCloudRenderPass _pass;

    public override void Create()
    {
        _pass?.Dispose();
        _pass = null;

        if (_shader == null)
            _shader = Shader.Find("Hidden/Pcx/URP Point Cloud");

        if (_shader == null)
        {
            Debug.LogError("Pcx URP point cloud shader could not be found.");
            return;
        }

        _pass = new PcxUrpPointCloudRenderPass(_shader)
        {
            renderPassEvent = _renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_pass == null || PcxUrpPointCloudRenderer.ActiveRenderers.Count == 0)
            return;

        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType == CameraType.Preview || cameraType == CameraType.Reflection)
            return;

        _pass.Setup(_layerMask);
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
        _pass = null;
    }

    private sealed class PcxUrpPointCloudRenderPass : ScriptableRenderPass
    {
        private static readonly int PointBufferId = Shader.PropertyToID("_PointBuffer");
        private static readonly int TransformId = Shader.PropertyToID("_Transform");
        private static readonly int TintId = Shader.PropertyToID("_Tint");
        private static readonly int PointSizeId = Shader.PropertyToID("_PointSize");

        private readonly Material _material;
        private readonly MaterialPropertyBlock _properties = new();
        private LayerMask _layerMask;

        public PcxUrpPointCloudRenderPass(Shader shader)
        {
            profilingSampler = new ProfilingSampler("PCX URP Point Clouds");
            _material = CoreUtils.CreateEngineMaterial(shader);
        }

        public void Setup(LayerMask layerMask)
        {
            _layerMask = layerMask;
        }

        [System.Obsolete("Compatibility-mode render pass used because this project has URP Render Graph disabled.", false)]
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(
                renderingData.cameraData.renderer.cameraColorTargetHandle,
                renderingData.cameraData.renderer.cameraDepthTargetHandle);
            ConfigureClear(ClearFlag.None, Color.clear);
        }

        [System.Obsolete("Compatibility-mode render pass used because this project has URP Render Graph disabled.", false)]
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            Camera camera = renderingData.cameraData.camera;
            CommandBuffer cmd = CommandBufferPool.Get("PCX URP Point Clouds");

            using (new ProfilingScope(cmd, profilingSampler))
            {
                foreach (PcxUrpPointCloudRenderer pointCloud in PcxUrpPointCloudRenderer.ActiveRenderers)
                {
                    if (pointCloud == null || !pointCloud.isActiveAndEnabled)
                        continue;

                    int layerBit = 1 << pointCloud.gameObject.layer;
                    if ((_layerMask.value & layerBit) == 0 || (camera.cullingMask & layerBit) == 0)
                        continue;

                    if (!pointCloud.TryGetPointBuffer(out ComputeBuffer pointBuffer, out int pointCount))
                        continue;

                    _properties.Clear();
                    _properties.SetBuffer(PointBufferId, pointBuffer);
                    _properties.SetMatrix(TransformId, pointCloud.transform.localToWorldMatrix);
                    _properties.SetColor(TintId, pointCloud.pointTint);
                    // A zero-sized disk is invisible; retain a tiny fallback so
                    // the component remains useful when animated from scripts.
                    _properties.SetFloat(PointSizeId, Mathf.Max(pointCloud.pointSize, 0.0001f));

                    cmd.DrawProcedural(
                        Matrix4x4.identity,
                        _material,
                        0,
                        MeshTopology.Triangles,
                        pointCount * 6,
                        1,
                        _properties);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            CoreUtils.Destroy(_material);
        }
    }
}
