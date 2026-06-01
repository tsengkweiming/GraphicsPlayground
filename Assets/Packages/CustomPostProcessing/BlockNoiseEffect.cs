using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/BlockEffect")]
    public class BlockEffect : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter speed = new ClampedFloatParameter(0f, 0f, 10f);
        public ClampedFloatParameter shift = new ClampedFloatParameter(0f, 0f, 1f);
        public Vector4Parameter scaleS = new Vector4Parameter(new Vector4(1f, 1f, 1f, 1f));
        public Vector4Parameter scaleL = new Vector4Parameter(new Vector4(1f, 1f, 1f, 1f));
        public Vector4Parameter wave = new Vector4Parameter(new Vector4(1f, 1f, -1f, -1f));
        public override bool IsActive() => mMaterial != null && (factor.value>0);
        private const string mShaderName = "Hidden/CustomPostProcess/BlockEffect";
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
            mMaterial.SetFloat("_Shift", shift.value);
            mMaterial.SetVector("_ScaleS", scaleS.value);
            mMaterial.SetVector("_ScaleL", scaleL.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}