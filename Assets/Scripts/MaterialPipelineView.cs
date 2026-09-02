using UnityEngine;

/// <summary>
/// Presentation side of the material pipeline. It only owns the output
/// renderer binding and does not decide how the pipeline is executed.
/// </summary>
public sealed class MaterialPipelineView
{
    private readonly Renderer _outputRenderer;
    private readonly string _outputPropertyName;
    private readonly MaterialPropertyBlock _propertyBlock = new MaterialPropertyBlock();

    public MaterialPipelineView(Renderer outputRenderer, string outputPropertyName)
    {
        _outputRenderer = outputRenderer;
        _outputPropertyName = outputPropertyName;
    }

    public void Present(Texture result)
    {
        if (!_outputRenderer || string.IsNullOrEmpty(_outputPropertyName))
            return;

        _outputRenderer.GetPropertyBlock(_propertyBlock);
        _propertyBlock.SetTexture(_outputPropertyName, result);
        _outputRenderer.SetPropertyBlock(_propertyBlock);
    }
}
