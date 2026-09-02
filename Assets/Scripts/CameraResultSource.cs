using UnityEngine;

/// <summary>
/// Optional camera-to-texture adapter. Assign an existing target texture when
/// the camera already renders off-screen; otherwise this component can create
/// and own one so the camera result is available to a material pipeline.
/// </summary>
[DisallowMultipleComponent]
public sealed class CameraResultSource : MonoBehaviour
{
    [SerializeField] private Camera sourceCamera;
    [SerializeField] private RenderTexture targetTexture;
    [SerializeField] private bool createTargetTextureIfMissing = true;
    [SerializeField] private Vector2Int captureSize = new Vector2Int(1920, 1080);

    private RenderTexture _ownedTexture;
    private RenderTexture _originalTargetTexture;

    public Texture Result => _ownedTexture ? _ownedTexture : targetTexture ? targetTexture : sourceCamera ? sourceCamera.targetTexture : null;

    private void OnEnable()
    {
        if (!sourceCamera)
            sourceCamera = GetComponent<Camera>();

        if (!sourceCamera || targetTexture || sourceCamera.targetTexture || !createTargetTextureIfMissing)
            return;

        _originalTargetTexture = sourceCamera.targetTexture;

        int width = Mathf.Max(1, captureSize.x > 0 ? captureSize.x : Screen.width);
        int height = Mathf.Max(1, captureSize.y > 0 ? captureSize.y : Screen.height);

        _ownedTexture = new RenderTexture(width, height, 24, RenderTextureFormat.Default)
        {
            name = $"{sourceCamera.name} Camera Result",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        _ownedTexture.Create();
        sourceCamera.targetTexture = _ownedTexture;
    }

    private void OnDisable()
    {
        if (sourceCamera && sourceCamera.targetTexture == _ownedTexture)
            sourceCamera.targetTexture = _originalTargetTexture;

        if (_ownedTexture)
        {
            _ownedTexture.Release();

            if (Application.isPlaying)
                Destroy(_ownedTexture);
            else
                DestroyImmediate(_ownedTexture);

            _ownedTexture = null;
        }
    }
}
