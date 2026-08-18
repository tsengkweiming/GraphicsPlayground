using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/Cross")]
    public class DiffusionBlur : CustomPostProcessing
    {
        public ClampedFloatParameter diffusionRate = new ClampedFloatParameter(0f, 0f, 2f);
        public ClampedFloatParameter chromaOffset = new ClampedFloatParameter(0f, 0f, 0.01f);
        public override bool IsActive() => mMaterial != null;
        private const string mShaderName = "Hidden/CustomPostProcess/DiffusionBlur";
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
            mMaterial.SetFloat("_DiffusionRate", diffusionRate.value);
            mMaterial.SetFloat("_ChromaOffset", chromaOffset.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}