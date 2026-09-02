using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Runtime state and stage wiring for a material pipeline.
/// The model does not know how the final texture is displayed.
/// </summary>
public sealed class MaterialPipelineModel
{
    private readonly IReadOnlyList<MaterialPipelineController.MaterialPipeline> _stages;

    public Texture Source { get; private set; }
    public Texture Result { get; private set; }

    public MaterialPipelineModel(IReadOnlyList<MaterialPipelineController.MaterialPipeline> stages)
    {
        _stages = stages;
    }

    public void SetSource(Texture source)
    {
        Source = source;
    }

    public void Execute()
    {
        Texture previousResult = Source;

        if (_stages != null)
        {
            foreach (MaterialPipelineController.MaterialPipeline stage in _stages)
            {
                ShaderController controller = stage?.controller;
                if (!controller || stage.byPass)
                    continue;

                controller.Source = previousResult;

                if (controller.Material && !string.IsNullOrEmpty(stage.textureName))
                    controller.Material.SetTexture(stage.textureName, previousResult);

                previousResult = controller.RenderTexture;
            }
        }

        Result = previousResult;
    }
}
