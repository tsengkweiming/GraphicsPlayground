using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/DitherEffect")]
    public class DitherEffect : CustomPostProcessing
    {
        public bool tst;
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter monoFactor = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter pixel = new ClampedFloatParameter(0f, 0f, 1000f);
        public ClampedFloatParameter color = new ClampedFloatParameter(0f, 0f, 20f);
        public ClampedFloatParameter ditherStrength = new ClampedFloatParameter(0.005f, 0f, 3f);
        public ClampedIntParameter maskCount = new (3, 0, 3);
        public ColorParameter paletteColor0 = new (new Color(0.384f, 0.776f, 0.949f, 1));
        public ColorParameter paletteColor1 = new (new Color(0.0f, 0.655f, 0.357f, 1));
        public ColorParameter paletteColor2 = new (new Color(1.0f, 0.533f, 0.533f, 1));
        public ColorParameter paletteColor3 = new (new Color(1.0f, 1.0f, 1.0f, 1));
        public override bool IsActive() => mMaterial != null && (factor.value>0);
        private const string mShaderName = "Hidden/CustomPostProcess/Dither";
        public override CustomPostProcessEvent evt => CustomPostProcessEvent.AfterPostProcess;
        public override int OrderInEvent => 100;
        
        public override void Setup()
        {
            if (mMaterial == null)
                mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);
        }

        public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
        {
            if (mMaterial == null) return;
            mMaterial.SetInt("_MaskCount", maskCount.value);
            mMaterial.SetFloat("_MonoFactor", monoFactor.value);
            mMaterial.SetFloat("_Factor", factor.value);
            mMaterial.SetFloat("_PixelFactor", pixel.value);
            mMaterial.SetFloat("_ColorFactor", color.value);
            mMaterial.SetFloat("_DitherStrength", ditherStrength.value);
            mMaterial.SetColorArray("_Palette", new [] { paletteColor0.value, paletteColor1.value, paletteColor2.value, paletteColor3.value });
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}