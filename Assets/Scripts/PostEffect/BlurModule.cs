using System;
using PostEffect.Common;
using PostEffect.PostEffectBase;
using PostEffect.Utility;
using RosettaUI;
using UnityEngine.Rendering;

namespace PostEffect
{
    [Serializable]
    public class BlurModuleParams : PostEffectModuleParamsBase, IElementCreator
    {
        public BlurType Type = BlurType.Gaussian;
        public BlurSampleCount SampleCount = BlurSampleCount.Normal;
        public int PreShrink = 2;
        public float SampleStep = 1f;
        public int Iteration = 1;

        public Element CreateElement(LabelElement label)
        {
            return UI.Column(
                UI.Field("Type", () => Type),
                UI.DynamicElementIf(
                    () => Type == BlurType.Gaussian,
                    () => UI.Field("SampleCount", () => SampleCount)
                ),
                UI.Field("PreShrink", () => PreShrink),
                UI.Field("SampleStep", () => SampleStep),
                UI.Field("Iteration", () => Iteration)
            );
        }
    }

    /// <summary>
    /// ぼかしをかけるモジュール
    /// </summary>
    public class BlurModule : PostEffectShaderModuleBase<BlurModuleParams>
    {
        protected override string ShaderName => "BlurModule";

        public override void OnApplyEffect(IPostEffectController controller, CommandBuffer commandBuffer)
        {
            BlurUtility.ApplyBlur(commandBuffer, controller.Buffer, _shader, Params, (int)Pass.Gaussian, (int)Pass.DownSample, (int)Pass.UpSample);
        }

        private enum Pass
        {
            Gaussian = 0,
            DownSample = 1,
            UpSample = 2,
        }
    }
}