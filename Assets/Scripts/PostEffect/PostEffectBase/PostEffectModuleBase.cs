using PostEffect.Common;
using RosettaUI;
using UnityEngine;
using UnityEngine.Rendering;

namespace PostEffect.PostEffectBase
{
   /// <summary>
    /// ポストエフェクトを適用するモジュールの基底クラス
    /// </summary>
    public abstract class PostEffectModuleBase<TParams> : MonoBehaviour, IPostEffectModule
        where TParams : PostEffectModuleParamsBase, new()
    {
        public virtual bool IsActive { get => _isActive; set => _isActive = value; }
        public virtual int ProcessStep { get => _processStep; set => _processStep = value; }
        public virtual Color EffectColor => Color.gray;
        public virtual string DetailText => "";
        public virtual IPostEffectModuleParams EffectParamsContainer { get => _effectParamsContainer; set => _effectParamsContainer = (EffectParamsContainer<TParams>)value; }

        [SerializeField] protected bool _isActive = true;
        [SerializeField] protected int _processStep;
        [SerializeField] protected EffectParamsContainer<TParams> _effectParamsContainer = new();

        protected IIndividualInfoProvider _individualInfoProvider = null;

        protected TParams Params
        {
            get
            {
                if (_individualInfoProvider == null)
                {
                    return _effectParamsContainer.SharedEffectParams;
                }

                var target = _individualInfoProvider.CurrentInfo;
                if (target == null)
                {
                    return _effectParamsContainer.SharedEffectParams;
                }

                for (var i = 0; i < _effectParamsContainer.SpecificEffectParams.Count; i++)
                {
                    var effectParams = _effectParamsContainer.SpecificEffectParams[i];

                    if (effectParams.IsActive && effectParams.Target == target)
                    {
                        return effectParams.Params;
                    }
                }

                return _effectParamsContainer.SharedEffectParams;
            }
        }

        public TParams EffectParams
        {
            set => _effectParamsContainer.SharedEffectParams = value;
        }

        #region IPosrEffectModule
        /// <summary>
        /// 初期化時
        /// </summary>
        public virtual void OnInitialize(IPostEffectController controller)
        {
            _effectParamsContainer ??= new EffectParamsContainer<TParams>();
            _individualInfoProvider = controller.IndividualInfoProvider;
        }

        /// <summary>
        /// 終了時
        /// </summary>
        public virtual void OnDeinitialize(IPostEffectController controller) { }

        /// <summary>
        /// エフェクトをかける
        /// </summary>
        public abstract void OnApplyEffect(IPostEffectController controller, CommandBuffer commandBuffer);

        /// <summary>
        /// 追加のUI
        /// </summary>
        public virtual Element AdditiveElement()
        {
            return null;
        }
        #endregion
    }

    /// <summary>
    /// ポストエフェクトを適用するモジュールの基底クラス
    /// </summary>
    public abstract class PostEffectShaderModuleBase<TParams> : PostEffectModuleBase<TParams>
        where TParams : PostEffectModuleParamsBase, new()
    {
        protected abstract string ShaderName { get; }
        protected Material _shader;

        /// <summary>
        /// 初期化時
        /// </summary>
        public override void OnInitialize(IPostEffectController controller)
        {
            base.OnInitialize(controller);
            _shader = new Material(Resources.Load<Shader>(ShaderName));
        }

        /// <summary>
        /// 終了時
        /// </summary>
        public override void OnDeinitialize(IPostEffectController controller)
        {
            if (_shader is not null)
            {
                DestroyImmediate(_shader);
            }
        }
    }
}