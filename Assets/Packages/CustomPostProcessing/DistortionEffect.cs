using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/DistortionEffect")]
    public class DistortionEffect : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter speed = new ClampedFloatParameter(0f, 0f, 10f);
        public ClampedFloatParameter scale = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter border = new ClampedFloatParameter(0f, 0f, 1f);
        public override bool IsActive() => mMaterial != null && factor.value > 0.0f;
        private const string mShaderName = "Hidden/CustomPostProcess/DistortionEffect";
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
            mMaterial.SetFloat("_T", factor.value);
            mMaterial.SetFloat("_Speed", speed.value);
            mMaterial.SetFloat("_Scale", scale.value);
            mMaterial.SetFloat("_Border", border.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}