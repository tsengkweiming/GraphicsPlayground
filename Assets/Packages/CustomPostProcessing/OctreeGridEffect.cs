using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/OctreeGridEffect")]
    public class OctreeGridEffect : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new (0f, 0f, 1f);
        public FloatParameter size = new (1.0f);
        public FloatParameter zFactor = new (0.2f);
        public IntParameter cellCount = new (3);
        public Vector3Parameter cellSize = new (Vector3.one * 0.5f);
        public ClampedFloatParameter zFactor2 = new (-0.04f, -0.3f, -0.03f);
        public ColorParameter borderColor = new (Color.white);
        public ClampedFloatParameter borderShowRate = new (0.2f, 0f, 1f);
        public override bool IsActive() => mMaterial != null && factor.value > 0.0f;
        private const string mShaderName = "Hidden/CustomPostProcess/OctreeGridEffect";
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
            mMaterial.SetFloat("_Size", size.value);
            mMaterial.SetFloat("_Z", zFactor.value);
            mMaterial.SetInt("_CellCount", cellCount.value);
            mMaterial.SetVector("_CellSize", cellSize.value);
            mMaterial.SetFloat("_Z2", zFactor2.value);
            mMaterial.SetColor("_BorderColor", borderColor.value);
            mMaterial.SetFloat("_BorderRate", borderShowRate.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}