using RosettaUI;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace PostEffect.PostEffectBase
{
    /// <summary>
    /// ポストエフェクトを適用するモジュールのパラメータのインターフェース
    /// </summary>
    public interface IPostEffectModuleParams { }

    /// <summary>
    /// ポストエフェクトを適用するモジュールのパラメータの基底クラス
    /// </summary>
    [Serializable]
    public class PostEffectModuleParamsBase : IPostEffectModuleParams { }

    /// <summary>
    /// 特定のパラメータを格納するクラス
    /// </summary>
    /// <typeparam name="TParams"></typeparam>
    [Serializable]
    public class SpecificEffectParams<TParams>
    where TParams : PostEffectModuleParamsBase, new()
    {
        public bool IsActive = true;
        [IndividualInfoDropDown]
        public string Target = "";
        public TParams Params = new();
    }

    /// <summary>
    /// エフェクトのパラメータ群を格納するクラス
    /// </summary>
    [Serializable]
    public class EffectParamsContainer<TParams> : IPostEffectModuleParams, IElementCreator
        where TParams : PostEffectModuleParamsBase, new()
    {
        public EffectParamsContainer() { }
        public EffectParamsContainer(TParams sharedEffectParams)
        {
            SharedEffectParams = sharedEffectParams;
        }

        public TParams SharedEffectParams = new();
        public List<SpecificEffectParams<TParams>> SpecificEffectParams = new();

        #region UI
        public virtual Element CreateElement(LabelElement label)
        {
            return UI.Column(
                UI.Indent(
                    UI.Column(
                        UI.Field(null, () => SharedEffectParams),
                        UI.Space().SetHeight(3f),
                        CopyPasteButtons(SharedEffectParams)
                    )
                ),
                UI.Space().SetHeight(5f),
                UI.List("Param Overrides",
                    () => SpecificEffectParams,
                    (_, index) =>
                    {
                        var effectParams = SpecificEffectParams[index];

                        return UI.Fold(UI.Label(() => effectParams.Target == "" ? "Not Set" : effectParams.Target),
                            UI.Field(null, () => effectParams).Open(),
                            UI.Space().SetHeight(3f),
                            CopyPasteButtons(effectParams.Params)
                        );
                    }
                )
            );

            Element CopyPasteButtons(TParams effectParams)
            {
                var copyButton = UI.Button("Copy", () =>
                {
                    GUIUtility.systemCopyBuffer = JsonUtility.ToJson(effectParams);
                }).SetBackgroundColor(Color.blue * 0.5f).SetWidth(70f);

                var pasteButton = UI.Button("Paste", () =>
                {
                    try
                    {
                        JsonUtility.FromJsonOverwrite(GUIUtility.systemCopyBuffer, effectParams);
                    }
                    catch (Exception)
                    {
                        // ignored
                    }
                }).SetBackgroundColor(Color.red * 0.5f).SetWidth(70f);

                return UI.Row(
                    UI.Space(),
                    copyButton,
                    pasteButton
                );
            }
        }
        #endregion
    }
}