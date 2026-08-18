using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace GraphicsPlayground.CustomPostProcessing
{
    [Serializable]
    [VolumeComponentMenu("Custom Post-processing/Temporal Diffusion")]
    [SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
    public sealed class TemporalDiffusion : VolumeComponent, IPostProcessComponent
    {
        [Tooltip("Enables the temporal diffusion effect.")]
        public BoolParameter enableEffect = new(false);

        [Tooltip("Blends between the untouched camera image and the accumulated result.")]
        public ClampedFloatParameter intensity = new(0.9f, 0.0f, 1.0f);

        [Tooltip("Amount of the previous frame retained. Higher values create longer trails.")]
        public ClampedFloatParameter feedback = new(0.92f, 0.0f, 0.995f);

        [Tooltip("Per-frame history fade. Lower values erase trails faster.")]
        public ClampedFloatParameter historyDecay = new(0.995f, 0.85f, 1.0f);

        [Tooltip("Distance, in pixels, between samples used by the diffusion operator.")]
        public ClampedFloatParameter diffusionRadius = new(1.25f, 0.0f, 6.0f);

        [Tooltip("Stable heat-equation coefficient. The upper limit of 0.249 avoids runaway feedback.")]
        public ClampedFloatParameter diffusionRate = new(0.18f, 0.0f, 0.249f);

        [Tooltip("RGB history sample separation in pixels.")]
        public ClampedFloatParameter chromaticSeparation = new(1.4f, 0.0f, 8.0f);

        [Tooltip("Screen-space direction used to separate red and blue history samples.")]
        public Vector2Parameter chromaticDirection = new(new Vector2(1.0f, 0.35f));

        [Tooltip("Strength, in pixels, of the slowly animated history advection.")]
        public ClampedFloatParameter flowStrength = new(0.45f, 0.0f, 4.0f);

        [Tooltip("Spatial frequency of the procedural flow field.")]
        public ClampedFloatParameter flowScale = new(3.0f, 0.25f, 12.0f);

        [Tooltip("Animation rate of the procedural flow field.")]
        public ClampedFloatParameter flowSpeed = new(0.2f, -2.0f, 2.0f);

        [Tooltip("Makes changing pixels hold slightly more history than still pixels.")]
        public ClampedFloatParameter motionResponse = new(3.0f, 0.0f, 12.0f);

        public bool IsActive() => enableEffect.value && intensity.value > 0.0f;

        [Obsolete("Unused by URP since 2023.1.", false)]
        public bool IsTileCompatible() => false;
    }
}
