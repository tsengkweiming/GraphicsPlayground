using System;
using System.Collections.Generic;
using System.Linq;
using PostEffect.Common;
using UnityEngine;
using UnityEngine.Rendering;

namespace PostEffect.PostEffectBase
{
    public abstract class PostEffectControllerBase : MonoBehaviour, IPostEffectController
    {
        protected List<IPostEffectModule> _modules;
        protected SwapBuffer<RenderTexture> _buffer;
        protected CommandBuffer _commandBuffer;
        protected int _outputIndex = 0;

        #region IPostEffectController
        public bool IsInited { get; protected set; } = false;
        public bool IsOutputBlack { get; set; } = false;
        public abstract Vector2Int Resolution { get; }
        public virtual Vector2Int ScaledResolution => Resolution;
        public virtual SwapBuffer<RenderTexture> Buffer => _buffer;
        public virtual IIndividualInfoProvider IndividualInfoProvider { get; } = null;
        public IEnumerable<IPostEffectModule> Modules => _modules;
        #endregion
        
        protected internal virtual void Initialize()
        {
            _modules = GetComponents<IPostEffectModule>().OrderBy(m => m.ProcessStep).ToList();
            _outputIndex = _modules.Count - 1;
            foreach (var module in _modules)
            {
                module.OnInitialize(this);
            }

            _commandBuffer = new CommandBuffer { name = $"{gameObject.name} PostEffect" };
        }

        protected internal virtual void Deinitialize()
        {
            if (_modules is null) return;

            foreach (var module in _modules)
            {
                module.OnDeinitialize(this);
            }

            _commandBuffer?.Dispose();
            _commandBuffer = null;
        }
        
        protected virtual void GenerateBufferTexture()
        {
            Debug.Log("Generate buffer texture");
            if (_buffer != null && _buffer.Read.width == ScaledResolution.x && _buffer.Read.height == ScaledResolution.y)
                return;

            if (_buffer != null)
            {
                _buffer.Dispose();
                _buffer = null;
            }

            _buffer = new SwapBuffer<RenderTexture>
            (
                () => new RenderTexture(ScaledResolution.x, ScaledResolution.y, 0, RenderTextureFormat.Default)
                {
                    filterMode = FilterMode.Point
                },
                (tex) =>
                {
                    if (tex == null)
                        return;
                    tex.Release();
                });
            Debug.Log("newed SwapBuffer");
        }
        
        protected internal virtual void AddModule(Type type, int processStep, bool isActive = true, IPostEffectModuleParams effectParamsContainer = null, bool needInitialize = true)
        {
            if (gameObject.AddComponent(type) is IPostEffectModule module)
            {
                module.ProcessStep = processStep;
                module.IsActive = isActive;
                module.EffectParamsContainer = effectParamsContainer;
                _modules.Add(module);
                _outputIndex = _modules.Count - 1;

                if (needInitialize)
                    module.OnInitialize(this);
            }
            else
            {
                Debug.LogError($"[PostEffectManager] Failed to add component. (Type: {type})");
            }
        }
        
        protected internal virtual void RemoveModule(IPostEffectModule module, bool immediately = false)
        {
            module.OnDeinitialize(this);
            _modules.Remove(module);
            if (immediately)
            {
                DestroyImmediate(module as Component);
            }
            else
            {
                Destroy(module as Component);
            }
            for (int i = 0; i < _modules.Count; i++)
            {
                _modules[i].ProcessStep = i;
            }
        }
        
        protected internal virtual void SortModules()
        {
            _modules = _modules.OrderBy(m => m.ProcessStep).ToList();
            _outputIndex = _modules.Count - 1;
        }

        protected IEnumerable<Type> GetModuleTypes<T>() where T : IPostEffectModule
        {
            var interfaceType = typeof(T);
            var assemblies = AppDomain.CurrentDomain.GetAssemblies();

            foreach (var assembly in assemblies)
            {
                var types = assembly.GetTypes()
                    .Where(c => c.GetInterfaces().Any(t => t == interfaceType) && c.IsClass && !c.IsGenericType && !c.IsAbstract);

                foreach (var type in types)
                {
                    yield return type;
                }
            }
        }
        
        #region IPostEffectController
        public virtual void ApplyEffect()
        {
            if (_modules is null) return;

            if (IsOutputBlack)
            {
                Graphics.Blit(Texture2D.blackTexture, _buffer.Read);
            }

            _outputIndex = Mathf.Min(_outputIndex, _modules.Count - 1);

            _commandBuffer.Clear();
            for (int i = 0; i <= _outputIndex; i++)
            {
                var module = _modules[i];
                if (!module.IsActive) continue;
                module.OnApplyEffect(this, _commandBuffer);
            }
            Graphics.ExecuteCommandBuffer(_commandBuffer);
        }

        public abstract void RegisterTexture(CommandBuffer commandBuffer, string key, Texture texture);

        public abstract void RegisterTexture(CommandBuffer commandBuffer, string key, RenderTargetIdentifier texture,
            int width, int height);

        public abstract Texture GetTexture(string key);
        #endregion
    }
}