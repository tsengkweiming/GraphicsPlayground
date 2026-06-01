using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/InverseEffect")]
    public class InverseEffect : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter scale = new ClampedFloatParameter(0f, 0f, 100f);
        public ClampedFloatParameter power = new ClampedFloatParameter(0f, 0f, 5f);
        public override bool IsActive() => mMaterial != null && (factor.value > 0);
        private const string mShaderName = "Hidden/CustomPostProcess/InverseEffect";
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
            mMaterial.SetFloat("_Scale", scale.value);
            mMaterial.SetFloat("_Power", power.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}