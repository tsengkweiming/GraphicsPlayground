using UnityEngine;

namespace Common
{
    public abstract class EffectController : MonoBehaviour
    {
        [SerializeField] private int _materialIndex;
        protected Renderer _targetRenderer;
        protected MaterialPropertyBlock _propertyBlock;

        protected virtual void OnEnable()
        {
            if (_targetRenderer == null)
            {
                _targetRenderer = GetComponent<Renderer>();
            }

            if (_propertyBlock == null)
            {
                _propertyBlock = new MaterialPropertyBlock();
            }
        }

        protected abstract void Tick(float deltaTime);
        
        protected virtual Material GetTargetMaterial(out int index)
        {
            Material[] materials = _targetRenderer.sharedMaterials;
            if (materials == null || materials.Length == 0)
            {
                index = 0;
                return null;
            }

            index = Mathf.Clamp(_materialIndex, 0, materials.Length - 1);
            return materials[index];
        }
    }
}