using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[DisallowMultipleRendererFeature]
public class BlurRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private Shader _shader;
    [SerializeField] private RenderPassEvent _renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    private BlurRenderPass _blurRenderPass;
    
    public override void Create()
    {
        _blurRenderPass?.Dispose();
        _blurRenderPass = null;

        _shader = Shader.Find("CustomEffects/Blur");
        if (_shader == null) return;
        _blurRenderPass = new BlurRenderPass(_shader)
        {
            renderPassEvent = _renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_blurRenderPass == null) return;
        if (renderingData.cameraData.cameraType != CameraType.Game) return;
        
        if (_blurRenderPass.UpdateBlurSettings() == false) return;
        
        renderer.EnqueuePass(_blurRenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        _blurRenderPass?.Dispose();
        _blurRenderPass = null;
    }
}

[Serializable]
public class BlurSettings
{
    [Range(0, 0.4f)] public float horizontalBlur;
    [Range(0, 0.4f)] public float verticalBlur;
}
