using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/Blur")]
    public class Blur : CustomPostProcessing
    {
        public ClampedFloatParameter factor = new ClampedFloatParameter(0f, 0f, 1f);
        public IntParameter lod = new IntParameter(0);
        public Vector2Parameter lerpInStartEnd = new Vector2Parameter(new Vector2(1f, 1f));
        public Vector2Parameter lerpOutStartEnd = new Vector2Parameter(new Vector2(1f, 1f));
        public ClampedFloatParameter maskIntensity = new ClampedFloatParameter(0f, 0f, 1f);
        public ClampedFloatParameter contrast = new ClampedFloatParameter(0f, 0f, 1f);
        public IntParameter iterations = new IntParameter(3);
        public FloatParameter blurSize = new FloatParameter(1.0f);
        public FloatParameter gain = new FloatParameter(1.0f);
        public FloatParameter peak = new FloatParameter(1.0f);
        public FloatParameter threshold = new FloatParameter(0f);
        public FloatParameter intensity = new FloatParameter(1.0f);
        public TextureParameter alphaMask = new TextureParameter(null);
        
        // RTHandles for temporary allocations to replace RenderTexture.GetTemporary
        private RTHandle m_DownsampledRT;
        private RTHandle m_TmpRT0;
        private RTHandle m_TmpRT1;
        public override bool IsActive() => mMaterial != null && factor.value > 0;
        private const string mShaderName = "Kitte/FastBlur";
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
            
            // 1. Calculate downsampled dimensions based on your original logic
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            int width = Mathf.Max(1, desc.width >> lod.value);
            int height = Mathf.Max(1, desc.height >> lod.value);
            
            // Configure descriptors for intermediate passes
            RenderTextureDescriptor targetDesc = desc;
            targetDesc.width = width;
            targetDesc.height = height;
            targetDesc.depthBufferBits = 0;
            targetDesc.colorFormat = RenderTextureFormat.ARGB32;
            
            // 2. Safely allocate/reallocate internal RTHandles
            RenderingUtils.ReAllocateIfNeeded(ref m_DownsampledRT, targetDesc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_BlurDownsampled");
            RenderingUtils.ReAllocateIfNeeded(ref m_TmpRT0, targetDesc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_BlurTmp0");
            RenderingUtils.ReAllocateIfNeeded(ref m_TmpRT1, targetDesc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_BlurTmp1");
            
            // ==========================================
            // STAGE 1: AddMask Logic
            // ==========================================
            BlitToTarget(cmd, source, m_DownsampledRT, -1);
            
            // mMaterial.SetVector("_LerpInStartEnd", lerpInStartEnd.value);
            // mMaterial.SetVector("_LerpOutStartEnd", lerpOutStartEnd.value);
            // mMaterial.SetFloat("_MaskIntensity", maskIntensity.value);
            // mMaterial.SetFloat("_Contrast", contrast.value);
            //
            // // Use alphaMask volume parameter if provided, otherwise fall back to source
            // Texture maskTex = alphaMask.value != null ? alphaMask.value : source.rt;
            // mMaterial.SetTexture("_AlphaMask", maskTex);
            // // Blit downsampled texture through Pass 5 into m_TmpRT0
            // BlitToTarget(cmd, m_DownsampledRT, m_TmpRT0, 5);
            
            // ==========================================
            // STAGE 2: Multi-iteration Blur Logic
            // ==========================================
            int iters = Mathf.Clamp(iterations.value, 0, 10);
            RTHandle currentSrc = m_TmpRT0;
            RTHandle currentDst = m_TmpRT1;
            
            for (int i = 0; i < iters; i++)
            {
                // bool enableKeyword = (i == iters - 1);
                // if (enableKeyword)
                // {
                //     cmd.EnableShaderKeyword(mMaterial, new LocalKeyword(mMaterial.shader, "BLUR_GAIN"));
                //     mMaterial.SetFloat("_Gain", gain.value);
                // }
                // else
                // {
                //     cmd.DisableShaderKeyword(mMaterial, new LocalKeyword(mMaterial.shader, "BLUR_GAIN"));
                // }
            
                for (int pass = 2; pass < 4; pass++)
                {
                    float iterationOffs = i;
                    float widthMod = 1f / (1f * (1 << 2));
                    var offset = new Vector2(blurSize.value * widthMod + iterationOffs, -blurSize.value * widthMod - iterationOffs);
                
                    mMaterial.SetVector("_BlurParam", new Vector3(peak.value, threshold.value, intensity.value));
                    mMaterial.SetVector("_Offset", offset);
            
                    BlitToTarget(cmd, currentSrc, currentDst, pass);
                
                    // Swap RTHandle references for the ping-pong blur sequence
                    (currentSrc, currentDst) = (currentDst, currentSrc);
                }
            }
        }
        
        /// <summary>
        /// Helper method using underlying CustomPostProcessing.Draw architecture
        /// </summary>
        private void BlitToTarget(CommandBuffer cmd, RTHandle src, RTHandle dst, int pass)
        {
            Draw(cmd, src, dst, pass);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}