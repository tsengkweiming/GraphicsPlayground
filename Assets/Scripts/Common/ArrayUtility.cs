using System;
using System.Runtime.InteropServices;

public static class ArrayUtility
{
    public static bool Equals<T>(T[] a, T[] b) where T : struct
    {
        if (a == null && b == null) return true;
        if (a == null || b == null) return false;
        if (a.Length != b.Length)   return false;

        // Compare raw bytes — works perfectly for blittable structs
        var spanA = MemoryMarshal.AsBytes(a.AsSpan());
        var spanB = MemoryMarshal.AsBytes(b.AsSpan());
        return spanA.SequenceEqual(spanB);
    }
}
