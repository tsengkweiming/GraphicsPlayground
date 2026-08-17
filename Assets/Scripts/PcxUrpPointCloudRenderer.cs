using System.Collections.Generic;
using UnityEngine;
using Pcx;

/// <summary>
/// URP-compatible point cloud source component.
///
/// Add PcxUrpPointCloudRendererFeature to the URP renderer data asset and add
/// this component to the same GameObject as the point cloud. The component is
/// deliberately separate from Pcx.PointCloudRenderer so the package remains
/// untouched and can still be updated normally.
/// </summary>
[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class PcxUrpPointCloudRenderer : MonoBehaviour
{
    private static readonly List<PcxUrpPointCloudRenderer> s_ActiveRenderers = new();

    [SerializeField] private PointCloudData _sourceData;
    [SerializeField] private Color _pointTint = new(0.5f, 0.5f, 0.5f, 1f);
    [SerializeField, Min(0f)] private float _pointSize = 0.05f;

    /// <summary>Optional PCX data asset. Used when sourceBuffer is not assigned.</summary>
    public PointCloudData sourceData
    {
        get => _sourceData;
        set => _sourceData = value;
    }

    public Color pointTint
    {
        get => _pointTint;
        set => _pointTint = value;
    }

    /// <summary>World-space diameter of each rendered point.</summary>
    public float pointSize
    {
        get => _pointSize;
        set => _pointSize = Mathf.Max(0f, value);
    }

    /// <summary>
    /// Optional externally-owned buffer, for example the output of a compute
    /// shader. This component never releases an externally assigned buffer.
    /// </summary>
    public ComputeBuffer sourceBuffer { get; set; }

    internal static IReadOnlyList<PcxUrpPointCloudRenderer> ActiveRenderers => s_ActiveRenderers;

    internal bool TryGetPointBuffer(out ComputeBuffer pointBuffer, out int pointCount)
    {
        pointBuffer = sourceBuffer != null ? sourceBuffer : _sourceData?.computeBuffer;
        pointCount = pointBuffer != null && pointBuffer.IsValid() ? pointBuffer.count : 0;
        return pointCount > 0;
    }

    private void OnEnable()
    {
        if (!s_ActiveRenderers.Contains(this))
            s_ActiveRenderers.Add(this);
    }

    private void OnDisable()
    {
        s_ActiveRenderers.Remove(this);
    }

    private void OnValidate()
    {
        _pointSize = Mathf.Max(0f, _pointSize);
    }
}
