using System.Collections.Generic;
using PostEffect.Common;
using UnityEngine;
using UnityEngine.Rendering;

namespace PostEffect.Utility
{
    /// <summary>
    /// Blur Type
    /// </summary>
    public enum BlurType
    {
        Gaussian = 0,
        Dual = 1000
    }

    /// <summary>
    /// Gaussian Blur Sample Count
    /// </summary>
    public enum BlurSampleCount
    {
        Disabled = -1,
        Low = 1000,         // sample num: 3, sigma: 2
        Normal = 2000,      // sample num: 5, sigma: 3
        High = 3000,        // sample num: 7, sigma: 4
        VeryHigh = 4000,    // sample num: 12, sigma: 6
        Ultra = 5000,       // sample num: 26, sigma: 12
    }

    public static class BlurUtility
    {
        #region Gaussian Blur

        private static readonly int _directionShaderKey = Shader.PropertyToID("_Direction");
        private static readonly int _sampleStepShaderKey = Shader.PropertyToID("_SampleStep");

        private static readonly int _horizontalTexShaderKey = Shader.PropertyToID("_HorizontalTex");
        private static readonly int _verticalTexShaderKey = Shader.PropertyToID("_VerticalTex");

        private static readonly string _blurKeywordPrefix = "BLUR_";
        private static readonly string _blurLowKeyword = $"{_blurKeywordPrefix}LOW";
        private static readonly string _blurNormalKeyword = $"{_blurKeywordPrefix}NORMAL";
        private static readonly string _blurHighKeyword = $"{_blurKeywordPrefix}HIGH";
        private static readonly string _blurVeryHighKeyword = $"{_blurKeywordPrefix}VERYHIGH";
        private static readonly string _blurUltraKeyword = $"{_blurKeywordPrefix}ULTRA";

        /// <summary>
        /// GaussianBlurをかける
        /// シェーダ側に _Direction と _SampleStep を設定する必要がある
        /// </summary>
        public static void ApplyBlur(SwapBuffer<RenderTexture> buf, Material mat, int pass, float sampleStep,
            int preShrink, int iteration, RenderTextureFormat format = RenderTextureFormat.Default,
            BlurSampleCount blurSampleCount = BlurSampleCount.Normal)
        {
            if (blurSampleCount == BlurSampleCount.Disabled) return;

            var oldFilterMode = buf.Read.filterMode;
            buf.Read.filterMode = FilterMode.Bilinear;
            buf.Write.filterMode = FilterMode.Bilinear;

            preShrink = Mathf.Max(preShrink, 1);
            mat.SetFloat(_sampleStepShaderKey, sampleStep);
            SetBlurQuality(mat, blurSampleCount);

            var horizontal =
                RenderTexture.GetTemporary(buf.Read.width / preShrink, buf.Read.height / preShrink, 0, format);
            var vertical =
                RenderTexture.GetTemporary(horizontal.width / preShrink, horizontal.height / preShrink, 0, format);

            for (int i = 0; i < iteration; i++)
            {
                // 横方向
                mat.SetVector(_directionShaderKey, Vector2.right);
                Graphics.Blit(buf.Read, horizontal, mat, pass);

                // 縦方向
                mat.SetVector(_directionShaderKey, Vector2.up);
                Graphics.Blit(horizontal, vertical, mat, pass);

                // もともとのサイズにもどす
                Graphics.Blit(vertical, buf.Write);

                buf.Swap();
            }

            RenderTexture.ReleaseTemporary(horizontal);
            RenderTexture.ReleaseTemporary(vertical);

            buf.Read.filterMode = oldFilterMode;
            buf.Write.filterMode = oldFilterMode;
        }

        /// <summary>
        /// CommandBufferを使ってGaussianBlurをかける
        /// シェーダ側に _Direction と _SampleStep を設定する必要がある
        /// </summary>
        public static void ApplyBlur(CommandBuffer commandBuffer, SwapBuffer<RenderTexture> buf, Material mat, int pass,
            float sampleStep, int preShrink, int iteration, RenderTextureFormat format = RenderTextureFormat.Default,
            BlurSampleCount blurSampleCount = BlurSampleCount.Normal)
        {
            if (blurSampleCount == BlurSampleCount.Disabled) return;

            // CommandBufferだとfilterModeが上書きされないので、shader側で対応
            // var oldFilterMode = buf.Read.filterMode;
            // buf.Read.filterMode = FilterMode.Bilinear;
            // buf.Write.filterMode = FilterMode.Bilinear;

            preShrink = Mathf.Max(preShrink, 1);
            commandBuffer.SetGlobalFloat(_sampleStepShaderKey, sampleStep);
            SetBlurQuality(mat, blurSampleCount);

            commandBuffer.GetTemporaryRT(_horizontalTexShaderKey, buf.Read.width / preShrink,
                buf.Read.height / preShrink, 0, FilterMode.Bilinear, format);
            commandBuffer.GetTemporaryRT(_verticalTexShaderKey, buf.Read.width / preShrink, buf.Read.height / preShrink,
                0, FilterMode.Bilinear, format);

            for (int i = 0; i < iteration; i++)
            {
                // 横方向
                commandBuffer.SetGlobalVector(_directionShaderKey,
                    Vector2.right); // matを使うと値が上書きされるので、commandBufferで設定が必須
                commandBuffer.Blit(buf.Read, _horizontalTexShaderKey, mat, pass);

                // 縦方向
                commandBuffer.SetGlobalVector(_directionShaderKey, Vector2.up); // matを使うと値が上書きされるので、commandBufferで設定が必須
                commandBuffer.Blit(_horizontalTexShaderKey, _verticalTexShaderKey, mat, pass);

                // もともとのサイズにもどす
                commandBuffer.Blit(_verticalTexShaderKey, buf.Write);

                buf.Swap();
            }

            commandBuffer.ReleaseTemporaryRT(_horizontalTexShaderKey);
            commandBuffer.ReleaseTemporaryRT(_verticalTexShaderKey);

            // buf.Read.filterMode = oldFilterMode;
            // buf.Write.filterMode = oldFilterMode;
        }

        private static void SetBlurQuality(Material mat, BlurSampleCount blurSampleCount)
        {
            switch (blurSampleCount)
            {
                case BlurSampleCount.Low:
                    mat.EnableKeyword(_blurLowKeyword);
                    mat.DisableKeyword(_blurNormalKeyword);
                    mat.DisableKeyword(_blurHighKeyword);
                    mat.DisableKeyword(_blurVeryHighKeyword);
                    mat.DisableKeyword(_blurUltraKeyword);
                    break;
                case BlurSampleCount.Normal:
                    mat.EnableKeyword(_blurNormalKeyword);
                    mat.DisableKeyword(_blurLowKeyword);
                    mat.DisableKeyword(_blurHighKeyword);
                    mat.DisableKeyword(_blurVeryHighKeyword);
                    mat.DisableKeyword(_blurUltraKeyword);
                    break;
                case BlurSampleCount.High:
                    mat.EnableKeyword(_blurHighKeyword);
                    mat.DisableKeyword(_blurLowKeyword);
                    mat.DisableKeyword(_blurNormalKeyword);
                    mat.DisableKeyword(_blurVeryHighKeyword);
                    mat.DisableKeyword(_blurUltraKeyword);
                    break;
                case BlurSampleCount.VeryHigh:
                    mat.EnableKeyword(_blurVeryHighKeyword);
                    mat.DisableKeyword(_blurLowKeyword);
                    mat.DisableKeyword(_blurNormalKeyword);
                    mat.DisableKeyword(_blurHighKeyword);
                    mat.DisableKeyword(_blurUltraKeyword);
                    break;
                case BlurSampleCount.Ultra:
                    mat.EnableKeyword(_blurUltraKeyword);
                    mat.DisableKeyword(_blurLowKeyword);
                    mat.DisableKeyword(_blurNormalKeyword);
                    mat.DisableKeyword(_blurHighKeyword);
                    mat.DisableKeyword(_blurVeryHighKeyword);
                    break;
            }
        }

        #endregion

        #region Dual Blur

        private static readonly int _prefilterID = Shader.PropertyToID("_PrefilterRT");
        private static readonly Dictionary<int, int> _levelDownSampleIdPairs = new();
        private static readonly Dictionary<int, int> _levelUpSampleIdPairs = new();
        private static readonly Stack<RenderTexture> _rtStack = new();

        // 縮小レベルに対応したシェーダIDを取得する
        private static int ToShaderID(this int level, string prefix, Dictionary<int, int> dic)
        {
            if (!dic.ContainsKey(level))
            {
                dic.Add(level, Shader.PropertyToID($"{prefix}{level}"));
            }

            return dic[level];
        }

        /// <summary>
        /// DualBlurをかける
        /// シェーダ側に _SampleStep を設定する必要がある
        /// </summary>
        public static void ApplyBlur(SwapBuffer<RenderTexture> buf, Material mat, int downSamplePass, int upSamplePass,
            float sampleStep, int preShrink, int iteration, RenderTextureFormat format = RenderTextureFormat.Default)
        {
            if (iteration <= 0) return;

            preShrink = Mathf.Max(preShrink, 1);
            mat.SetFloat(_sampleStepShaderKey, sampleStep);

            var preRt = RenderTexture.GetTemporary(Mathf.Max(buf.Read.width / preShrink),
                Mathf.Max(buf.Read.height / preShrink), 0, format);
            Graphics.Blit(buf.Read, preRt);
            _rtStack.Push(preRt);
            var last = preRt;
            for (int level = 0; level < iteration; level++)
            {
                var rt = RenderTexture.GetTemporary(Mathf.Max(last.width / 2, 1), Mathf.Max(last.height / 2, 1), 0,
                    format);
                Graphics.Blit(last, rt, mat, downSamplePass);
                _rtStack.Push(rt);
                last = rt;
            }

            for (int level = iteration - 1; level >= 0; level--)
            {
                var rt = RenderTexture.GetTemporary(last.width * 2, last.height * 2, 0, format);
                Graphics.Blit(last, rt, mat, upSamplePass);
                _rtStack.Push(rt);
                last = rt;
            }

            Graphics.Blit(last, buf.Write);
            buf.Swap();
            ;
            while (_rtStack.Count > 0)
            {
                RenderTexture.ReleaseTemporary(_rtStack.Pop());
            }
        }

        /// <summary>
        /// CommandBufferを使ってDualBlurをかける
        /// </summary>
        public static void ApplyBlur(CommandBuffer commandBuffer, SwapBuffer<RenderTexture> buf, Material mat,
            int downSamplePass, int upSamplePass, float sampleStep, int preShrink, int iteration,
            RenderTextureFormat format = RenderTextureFormat.Default)
        {
            if (iteration <= 0) return;

            preShrink = Mathf.Max(preShrink, 1);
            commandBuffer.SetGlobalFloat(_sampleStepShaderKey, sampleStep);

            var last = (ID: _prefilterID, width: Mathf.Max(buf.Read.width / preShrink, 1),
                height: Mathf.Max(buf.Read.height / preShrink, 1));
            commandBuffer.GetTemporaryRT(last.ID, last.width, last.height, 0, FilterMode.Bilinear, format);
            commandBuffer.Blit(buf.Read, last.ID);

            for (int level = 0; level < iteration; level++)
            {
                var id = level.ToShaderID("_DownSampleTex", _levelDownSampleIdPairs);
                var width = Mathf.Max(last.width / 2, 1);
                var height = Mathf.Max(last.height / 2, 1);
                commandBuffer.GetTemporaryRT(id, width, height, 0, FilterMode.Bilinear, format);
                commandBuffer.Blit(last.ID, id, mat, downSamplePass);
                last = (id, width, height);
            }

            for (int level = iteration - 1; level >= 0; level--)
            {
                var id = level.ToShaderID("_UpSampleTex", _levelUpSampleIdPairs);
                var width = last.width * 2;
                var height = last.height * 2;
                commandBuffer.GetTemporaryRT(id, width, height, 0, FilterMode.Bilinear, format);
                commandBuffer.Blit(last.ID, id, mat, upSamplePass);
                last = (id, width, height);
            }

            commandBuffer.Blit(last.ID, buf.Write);
            buf.Swap();

            foreach (var id in _levelDownSampleIdPairs.Values)
            {
                commandBuffer.ReleaseTemporaryRT(id);
            }

            foreach (var id in _levelUpSampleIdPairs.Values)
            {
                commandBuffer.ReleaseTemporaryRT(id);
            }

            commandBuffer.ReleaseTemporaryRT(_prefilterID);
        }

        #endregion

        public static void ApplyBlur(SwapBuffer<RenderTexture> buf, Material mat, BlurModuleParams blurParams,
            int gaussianBlurPass, int downSamplePass, int upSamplePass,
            RenderTextureFormat format = RenderTextureFormat.Default)
        {
            switch (blurParams.Type)
            {
                case BlurType.Gaussian:
                    ApplyBlur(buf, mat, gaussianBlurPass, blurParams.SampleStep, blurParams.PreShrink,
                        blurParams.Iteration, format, blurParams.SampleCount);
                    break;
                case BlurType.Dual:
                    ApplyBlur(buf, mat, downSamplePass, upSamplePass, blurParams.SampleStep, blurParams.PreShrink,
                        blurParams.Iteration, format);
                    break;
                default:
                    break;
            }
        }

        public static void ApplyBlur(CommandBuffer commandBuffer, SwapBuffer<RenderTexture> buf, Material mat,
            BlurModuleParams blurParams, int gaussianBlurPass, int downSamplePass, int upSamplePass,
            RenderTextureFormat format = RenderTextureFormat.Default)
        {
            switch (blurParams.Type)
            {

                case BlurType.Gaussian:
                    ApplyBlur(commandBuffer, buf, mat, gaussianBlurPass, blurParams.SampleStep, blurParams.PreShrink,
                        blurParams.Iteration, format, blurParams.SampleCount);
                    break;
                case BlurType.Dual:
                    ApplyBlur(commandBuffer, buf, mat, downSamplePass, upSamplePass, blurParams.SampleStep,
                        blurParams.PreShrink, blurParams.Iteration, format);
                    break;
                default:
                    break;
            }
        }

        /// <summary>
        /// 画素を平均化したリサイズを行う
        /// </summary>
        public static void ApplyHighQualityResize(RenderTexture source, RenderTexture target,
            Material afterResizeMat = null, int afterResizePass = 0)
        {
            Vector2Int resolution = new Vector2Int(source.width, source.height);

            // Todo: Blitの回数削減
            RenderTexture rt0 = RenderTexture.GetTemporary(resolution.x, resolution.y, 0, source.format,
                RenderTextureReadWrite.Linear);
            Graphics.Blit(source, rt0);
            while (true)
            {
                if (resolution is { x: 1, y: 1 }) break;
                resolution.x += resolution.x % 2 == 1 ? 1 : 0;
                resolution.y += resolution.y % 2 == 1 ? 1 : 0;
                resolution.x = resolution.x / 2 < target.width ? target.width : resolution.x / 2;
                resolution.y = resolution.y / 2 < target.height ? target.height : resolution.y / 2;
                if (resolution.x == target.width && resolution.y == target.height) break;

                var rt1 = RenderTexture.GetTemporary(resolution.x, resolution.y, 0, source.format,
                    RenderTextureReadWrite.Linear);
                Graphics.Blit(rt0, rt1);
                RenderTexture.ReleaseTemporary(rt0);
                rt0 = rt1;
            }

            if (afterResizeMat != null)
            {
                Graphics.Blit(rt0, target, afterResizeMat, afterResizePass);
            }
            else
            {
                Graphics.Blit(rt0, target);
            }

            RenderTexture.ReleaseTemporary(rt0);
        }
    }
}