using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[DisallowMultipleRendererFeature]
public sealed class ProceduralTextGIRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private RenderPassEvent _renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private ProceduralTextGIPass _pass;

    public override void Create()
    {
        _pass = new ProceduralTextGIPass
        {
            renderPassEvent = _renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_pass == null) return;

        Camera camera = renderingData.cameraData.camera;
        if (!ProceduralTextGIController.TryGetForCamera(camera, out var controller)) return;

        _pass.Setup(controller, _renderPassEvent);
        _pass.ConfigureInput(ScriptableRenderPassInput.Color);
        renderer.EnqueuePass(_pass);
    }

    private sealed class ProceduralTextGIPass : ScriptableRenderPass
    {
        private ProceduralTextGIController _controller;

        public void Setup(ProceduralTextGIController controller, RenderPassEvent passEvent)
        {
            _controller = controller;
            renderPassEvent = passEvent;
        }

        [System.Obsolete("Compatibility-mode render pass while Render Graph is disabled for this project.")]
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_controller == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("Procedural Text GI");
            _controller.RenderInto(cmd, renderingData.cameraData.renderer.cameraColorTargetHandle);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
