using System.Collections.Generic;
using PostEffect.PostEffectBase;
using UnityEngine;
using UnityEngine.Rendering;
namespace PostEffect.Common
{
    public interface IPostEffectController
    {
        /// <summary>
        /// 初期化されているかどうか
        /// </summary>
        bool IsInited { get; }

        /// <summary>
        /// 黒テクスチャを出力するかどうか
        /// </summary>
        bool IsOutputBlack { get; set; }

        /// <summary>
        /// 最終出力の解像度
        /// </summary>
        Vector2Int Resolution { get; }

        /// <summary>
        /// バッファの解像度
        /// </summary>
        Vector2Int ScaledResolution { get; }

        /// <summary>
        /// レンダーテクスチャのバッファ
        /// </summary>
        SwapBuffer<RenderTexture> Buffer { get; }

        /// <summary>
        /// 特定のパラメータを適用したい場合に使用する
        /// </summary>
        IIndividualInfoProvider IndividualInfoProvider { get; }

        /// <summary>
        /// このコントローラーに登録されているモジュールのリスト
        /// </summary>
        IEnumerable<IPostEffectModule> Modules { get; }

        /// <summary>
        /// エフェクトをかける
        /// </summary>
        void ApplyEffect();

        /// <summary>
        /// テクスチャを登録する
        /// </summary>
        void RegisterTexture(CommandBuffer commandBuffer, string key, Texture texture);

        /// <summary>
        /// テクスチャを登録する
        /// </summary>
        void RegisterTexture(CommandBuffer commandBuffer, string key, RenderTargetIdentifier texture, int width, int height);

        /// <summary>
        /// 登録されたテクスチャを取得する
        /// </summary>
        Texture GetTexture(string key);
    }
}