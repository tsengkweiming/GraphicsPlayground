using System;
using PostEffect.PostEffectBase;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace PostEffect
{
    public class PostEffectController : PostEffectControllerBase
    {
        [SerializeField] private Vector2Int _resolution;
        [SerializeField] protected RenderTexture _outputTexture;
        [SerializeField] protected GameObject _renderQuad;
        private Camera _targetCamera = null;
        private RenderTexture _cameraTexture;
        
        public override Vector2Int Resolution => _resolution;

        private void Start()
        {
            if (_targetCamera == null) _targetCamera = GetComponent<Camera>();
            
            GenerateCameraTexture();
            GenerateOutputTexture();
            GenerateBufferTexture();
            
            Initialize();
            
            IsInited = true;
        }

        private void Update()
        {
            if (_targetCamera == null) return;

            // カメラテクスチャからレンダリング
            Graphics.Blit(_cameraTexture, _buffer.Read);
            ApplyEffect();

            //output
            // レンダリング結果を出力テクスチャにコピー
            Graphics.Blit(_buffer.Read, _outputTexture);
            if(_renderQuad)
                _renderQuad.GetComponent<MeshRenderer>().material.mainTexture = _outputTexture;
                // _renderQuad.GetComponent<MeshRenderer>().material.SetTexture("_MainTex", _outputTexture);
        }
        
        protected override void GenerateBufferTexture()
        {
            base.GenerateBufferTexture();
            // _buffer.AddTo(this);
        }
        
        private void GenerateCameraTexture()
        {
            if (_cameraTexture != null && _cameraTexture.width == ScaledResolution.x && _cameraTexture.height == ScaledResolution.y) return;

            if (_cameraTexture != null)
            {
                _cameraTexture.Release();
                _cameraTexture = null;
            }

            _cameraTexture = new RenderTexture(ScaledResolution.x, ScaledResolution.y, 24, RenderTextureFormat.Default)
            {
                filterMode = FilterMode.Point,
                depthStencilFormat = GraphicsFormat.D24_UNorm_S8_UInt
            };

            _targetCamera.targetTexture = _cameraTexture;
        }
        
        private void GenerateOutputTexture()
        {
            if (_outputTexture != null && _outputTexture.width == Resolution.x && _outputTexture.height == Resolution.y) return;

            if (_outputTexture != null)
            {
                _outputTexture.Release();
                _outputTexture = null;
            }

            _outputTexture = new RenderTexture(Resolution.x, Resolution.y, 0, RenderTextureFormat.Default)
            {
                filterMode = FilterMode.Point,
            }; //.AddTo(this);
        }

        private void OnDestroy()
        {
            _cameraTexture?.Release();
            _cameraTexture = null;

            Deinitialize();

            IsInited = false;
        }

        #region IPostEffectController
        public override void ApplyEffect()
        {
            if (_modules is null) return;
            
            if (IsOutputBlack)
            {
                Graphics.Blit(Texture2D.blackTexture, _buffer.Read);
            }
            
            // エフェクトをかける
            _outputIndex = Mathf.Min(_outputIndex, _modules.Count - 1);

            _commandBuffer.Clear();
            for (int i = 0; i <= _outputIndex; i++)
            {
                IPostEffectModule module = _modules[i];
                if (IsOutputBlack) continue; // && module is not SpoutSenderModule
                if (!module.IsActive) continue;
                module.OnApplyEffect(this, _commandBuffer);
            }
            Graphics.ExecuteCommandBuffer(_commandBuffer);
        }

        public override void RegisterTexture(CommandBuffer commandBuffer, string key, Texture texture)
        {
            throw new System.NotImplementedException();
        }

        public override void RegisterTexture(CommandBuffer commandBuffer, string key, RenderTargetIdentifier texture, int width, int height)
        {
            throw new System.NotImplementedException();
        }

        public override Texture GetTexture(string key)
        {
            throw new System.NotImplementedException();
        }

        #endregion
    }
}