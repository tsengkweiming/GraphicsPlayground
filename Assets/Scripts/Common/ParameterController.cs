using UnityEngine;

public abstract class ParmeterController<T> where T : ParmeterController<T>
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