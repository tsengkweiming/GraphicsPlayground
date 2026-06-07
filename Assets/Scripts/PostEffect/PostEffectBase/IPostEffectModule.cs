using PostEffect.Common;
using RosettaUI;
using UnityEngine;
using UnityEngine.Rendering;

namespace PostEffect.PostEffectBase
{
    /// <summary>
    /// ポストエフェクトを適用するモジュールのインターフェース
    /// </summary>
    public interface IPostEffectModule
    {
        /// <summary>
        /// 有効かどうか
        /// </summary>
        public bool IsActive { get; set; }

        /// <summary>
        /// 処理順
        /// </summary>
        public int ProcessStep { get; set; }

        /// <summary>
        /// エフェクトの色(UI)
        /// </summary>
        public Color EffectColor { get; }

        /// <summary>
        /// エフェクトの詳細テキスト(UI)
        /// </summary>
        public string DetailText { get; }

        /// <summary>
        /// エフェクトの設定
        /// </summary>
        public IPostEffectModuleParams EffectParamsContainer { get; set; }

        /// <summary>
        /// 初期化時
        /// </summary>
        public void OnInitialize(IPostEffectController controller);

        /// <summary>
        /// 終了時
        /// </summary>
        public void OnDeinitialize(IPostEffectController controller);

        /// <summary>
        /// エフェクトをかける
        /// </summary>
        public void OnApplyEffect(IPostEffectController controller, CommandBuffer commandBuffer);

        public Element AdditiveElement();
    }
}