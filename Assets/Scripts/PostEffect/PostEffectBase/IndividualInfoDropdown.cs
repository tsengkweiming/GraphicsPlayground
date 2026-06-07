using RosettaUI;
using System.Linq;
using UnityEngine;

namespace PostEffect.PostEffectBase
{
    /// <summary>
    /// IndividualInfoProviderから取得した個別情報をドロップダウンで選択するための属性
    /// </summary>
    public class IndividualInfoDropDown : PropertyAttribute { }

    public static class IndividualInfoProviderExtension
    {
        public static void RegisterDropDownAttribute(this IIndividualInfoProvider provider)
        {
            UICustom.RegisterPropertyAttributeFunc<IndividualInfoDropDown, string>((attribute, label, binder) =>
            {
                return UI.Dropdown(label, binder, provider.Individuals.Select(i => i.Identifier));
            });
        }
    }
}