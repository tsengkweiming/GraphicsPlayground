using System;
using UnityEngine;

public class ShaderController : MonoBehaviour
{
    [SerializeField] protected Shader _shader;
    [SerializeField] protected Material _material;
    [SerializeField] protected bool _replaceRendererMaterial;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    protected virtual void Start()
    {
        EnsureMaterial();
        
        if(_replaceRendererMaterial)
            GetComponent<Renderer>().material = _material;
    }

    protected void EnsureMaterial()
    {
        if (!_material && _shader)
        {
            _material = new Material(_shader);
        }
    }

    protected virtual void OnDestroy()
    {
        if (_material != null)
        {
            if (Application.isPlaying)
            {
                Destroy(_material);
            }
            else
            {
                DestroyImmediate(_material);
            }
        }

        _material = null;
    }
}
