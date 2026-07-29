using System;
using UnityEngine;

public abstract class ShaderControllerParam<T> where T : ShaderControllerParam<T>
{
    public abstract void CopyFrom(T other);
    public abstract void MoveTowards(T target, float t);
    public abstract bool Approximately(T other);

    protected static TValue LerpValue<TValue>(TValue fromValue, TValue toValue, float t)
    {
        t = Mathf.Clamp01(t);

        if (typeof(TValue) == typeof(float))
        {
            return (TValue)(object)Mathf.Lerp((float)(object)fromValue, (float)(object)toValue, t);
        }

        if (typeof(TValue) == typeof(Vector2))
        {
            return (TValue)(object)Vector2.Lerp((Vector2)(object)fromValue, (Vector2)(object)toValue, t);
        }

        if (typeof(TValue) == typeof(Vector3))
        {
            return (TValue)(object)Vector3.Lerp((Vector3)(object)fromValue, (Vector3)(object)toValue, t);
        }

        if (typeof(TValue) == typeof(Color))
        {
            return (TValue)(object)Color.Lerp((Color)(object)fromValue, (Color)(object)toValue, t);
        }

        if (typeof(TValue) == typeof(int))
        {
            return toValue;
        }

        if (typeof(TValue).IsEnum)
        {
            return toValue;
        }

        return t < 0.5f ? fromValue : toValue;
    }

    protected static bool ApproximatelyValue<TValue>(TValue value, TValue other)
    {
        if (typeof(TValue) == typeof(float))
        {
            return Mathf.Approximately((float)(object)value, (float)(object)other);
        }

        if (typeof(TValue) == typeof(Vector2))
        {
            return ((Vector2)(object)value - (Vector2)(object)other).sqrMagnitude <= 0.000001f;
        }

        if (typeof(TValue) == typeof(Vector3))
        {
            return ((Vector3)(object)value - (Vector3)(object)other).sqrMagnitude <= 0.000001f;
        }

        if (typeof(TValue) == typeof(Color))
        {
            return ((Vector4)(Color)(object)value - (Vector4)(Color)(object)other).sqrMagnitude <= 0.000001f;
        }

        if (typeof(TValue) == typeof(int))
        {
            return (int)(object)value == (int)(object)other;
        }

        return Equals(value, other);
    }
}

public class ShaderController : MonoBehaviour
{
    [SerializeField] protected Shader _shader;
    [SerializeField] protected Material _material;
    [SerializeField] protected bool _replaceRendererMaterial;
    [SerializeField] protected float _interpolationSpeed = 2f;
    
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
