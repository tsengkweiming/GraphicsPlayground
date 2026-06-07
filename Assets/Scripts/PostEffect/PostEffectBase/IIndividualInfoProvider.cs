using System;
using System.Collections.Generic;

namespace PostEffect.PostEffectBase
{
    /// <summary>
    /// 個別の情報を取得するためのインターフェース
    /// </summary>
    public interface IIndividualInfoProvider
    {
        IndividualInfo CurrentInfo { get; }
        IEnumerable<IndividualInfo> Individuals { get; }
    }

    [Serializable]
    public class IndividualInfo
    {
        public string Identifier { get; set; }

        public static implicit operator string(IndividualInfo individual) => individual.Identifier;
    }
}