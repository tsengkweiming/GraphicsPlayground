using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    /// <summary>
    /// Camera-space approximation of the vertical pixel sorter used by the
    /// reference Shadertoy. The effect keeps the source image intact and
    /// pulls brighter samples along a configurable axis into long streaks.
    /// </summary>
    [VolumeComponentMenu("Custom Post-processing/Pixel Sort")]
    public sealed class PixelSort : CustomPostProcessing
    {
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 1f);
        public ClampedFloatParameter threshold = new ClampedFloatParameter(0.42f, 0f, 1f);
        public ClampedFloatParameter thresholdSoftness = new ClampedFloatParameter(0.08f, 0.001f, 0.5f);
        public ClampedFloatParameter streakLength = new ClampedFloatParameter(96f, 1f, 256f);
        public ClampedIntParameter samples = new ClampedIntParameter(24, 4, 32);
        public ClampedFloatParameter brightnessPower = new ClampedFloatParameter(1.35f, 0.25f, 4f);
        public ClampedFloatParameter breakUp = new ClampedFloatParameter(0.12f, 0f, 1f);
        public ClampedFloatParameter horizontal = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter reverse = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter animationAmount = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter animationSpeed = new ClampedFloatParameter(0.35f, 0f, 5f);

        private const string ShaderName = "Hidden/CustomPostProcess/PixelSort";

        public override bool IsActive() => mMaterial != null && intensity.value > 0.0001f;

        public override CustomPostProcessEvent evt => CustomPostProcessEvent.AfterPostProcess;

        public override int OrderInEvent => 0;

        public override void Setup()
        {
            if (mMaterial == null)
                mMaterial = CoreUtils.CreateEngineMaterial(ShaderName);
        }

        public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source,
            RTHandle destination)
        {
            if (mMaterial == null)
                return;

            var descriptor = renderingData.cameraData.cameraTargetDescriptor;
            var width = Mathf.Max(1, descriptor.width);
            var height = Mathf.Max(1, descriptor.height);

            mMaterial.SetFloat("_Intensity", intensity.value);
            mMaterial.SetFloat("_Threshold", threshold.value);
            mMaterial.SetFloat("_ThresholdSoftness", thresholdSoftness.value);
            mMaterial.SetFloat("_StreakLength", streakLength.value);
            mMaterial.SetFloat("_Samples", samples.value);
            mMaterial.SetFloat("_BrightnessPower", brightnessPower.value);
            mMaterial.SetFloat("_BreakUp", breakUp.value);
            mMaterial.SetFloat("_Horizontal", horizontal.value);
            mMaterial.SetFloat("_Reverse", reverse.value);
            mMaterial.SetFloat("_AnimationAmount", animationAmount.value);
            mMaterial.SetFloat("_AnimationSpeed", animationSpeed.value);
            mMaterial.SetVector("_SourceTexelSize", new Vector4(1f / width, 1f / height, width, height));

            Draw(cmd, source, destination, 0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
            mMaterial = null;
        }
    }
}
