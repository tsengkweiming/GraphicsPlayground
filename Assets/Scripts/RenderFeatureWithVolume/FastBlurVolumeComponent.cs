using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public enum FastBlurCompositeMode
{
    Blur,
    Screen,
    Add
}

[Serializable]
public sealed class FastBlurCompositeModeParameter : VolumeParameter<FastBlurCompositeMode>
{
    public FastBlurCompositeModeParameter(FastBlurCompositeMode value, bool overrideState = false) : base(value, overrideState)
    {
    }
}

[VolumeComponentMenu("Post-processing Custom/FastBlur")]
[VolumeRequiresRendererFeatures(typeof(FastBlurRendererFeature))]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
public sealed class FastBlurVolumeComponent : VolumeComponent, IPostProcessComponent
{
    public FastBlurVolumeComponent()
    {
        displayName = "FastBlur";
    }

    [Tooltip("Strength of the final blur composite.")]
    public MinFloatParameter intensity = new(1.0f, 0.0f);

    [Tooltip("Number of times the source is downsampled before blurring.")]
    public ClampedIntParameter downSample = new(2, 0, 6);

    [Tooltip("Number of vertical/horizontal blur iterations.")]
    public ClampedIntParameter iterations = new(3, 0, 10);

    [Tooltip("Base blur kernel width in downsampled texels.")]
    public ClampedFloatParameter blurSize = new(1.0f, 0.0001f, 8.0f);

    [Tooltip("How the blurred texture is composited back into the camera color.")]
    public FastBlurCompositeModeParameter compositeMode = new(FastBlurCompositeMode.Blur);

    [Tooltip("Render the blurred texture directly for debugging.")]
    public BoolParameter debugBlur = new(false);

    [Tooltip("Optional texture used by the shader mask pass.")]
    public TextureParameter alphaMask = new(null);

    [Tooltip("Strength of the optional mask texture.")]
    public ClampedFloatParameter maskIntensity = new(0.0f, 0.0f, 8.0f);

    [Tooltip("Mask contrast shaping.")]
    public ClampedFloatParameter contrast = new(1.0f, 0.0f, 8.0f);

    [Tooltip("Mask fade-in range.")]
    public Vector2Parameter lerpInStartEnd = new(new Vector2(0.0f, 1.0f));

    [Tooltip("Mask fade-out range.")]
    public Vector2Parameter lerpOutStartEnd = new(new Vector2(1.0f, 2.0f));

    public bool IsActive()
    {
        return intensity.value > 0.0f;
    }
}
