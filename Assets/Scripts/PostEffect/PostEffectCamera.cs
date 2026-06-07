using UnityEngine;
using UnityEngine.Rendering;

namespace PostEffect.PostEffectBase
{
    public class PostEffectCamera : PostEffectControllerBase
    {
        // Start is called once before the first execution of Update after the MonoBehaviour is created
        void Start()
        {
        
        }

        // Update is called once per frame
        void Update()
        {
        
        }

        public override Vector2Int Resolution { get; }
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
    }
}