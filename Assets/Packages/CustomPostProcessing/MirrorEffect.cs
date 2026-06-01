using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/MirrorEffect")]
    public class MirrorEffect : CustomPostProcessing
    {
        public BoolParameter horizontal = new BoolParameter(false);
        public BoolParameter left = new BoolParameter(false);
        public BoolParameter vertical = new BoolParameter(false);
        public BoolParameter up = new BoolParameter(false);
        public override bool IsActive() => mMaterial != null && (horizontal.value || left.value || vertical.value || up.value);
        private const string mShaderName = "Hidden/CustomPostProcess/MirrorEffect";
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
            mMaterial.SetFloat("_Horizontal", horizontal.value ? 1.0f : 0.0f);
            mMaterial.SetFloat("_Vertical", vertical.value ? 1.0f : 0.0f);
            mMaterial.SetFloat("_Left", left.value ? 1.0f : 0.0f);
            mMaterial.SetFloat("_Up", up.value ? 1.0f : 0.0f);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}