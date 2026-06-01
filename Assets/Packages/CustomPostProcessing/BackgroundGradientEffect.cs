using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/BackgroundGradientEffect")]
    public class BackgroundGradientEffect : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public ColorParameter color0 = new ColorParameter(Color.white);
        public ColorParameter color1 = new ColorParameter(Color.white);
        public ColorParameter color2 = new ColorParameter(Color.white);
        public ColorParameter color3 = new ColorParameter(Color.white);
        public ColorParameter color4 = new ColorParameter(Color.white);
        public Vector4Parameter position = new Vector4Parameter(Vector4.zero);
        public override bool IsActive() => mMaterial != null && (factor.value>0);
        private const string mShaderName = "Hidden/CustomPostProcess/BackgroundGradientEffect";
        public override CustomPostProcessEvent evt => CustomPostProcessEvent.BeforePostProcess;
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
            mMaterial.SetColor("_GradientColor0", color0.value);
            mMaterial.SetColor("_GradientColor1", color1.value);
            mMaterial.SetColor("_GradientColor2", color2.value);
            mMaterial.SetColor("_GradientColor3", color3.value);
            mMaterial.SetColor("_GradientColor4", color4.value);
            mMaterial.SetVector("_Pos0123", position.value);
            Draw(cmd,source,destination,0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}