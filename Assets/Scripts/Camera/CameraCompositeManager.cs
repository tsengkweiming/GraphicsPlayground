using System;
using System.Collections.Generic;
using Klak.Spout;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class CameraCompositeManager : MonoBehaviour
{
    [Serializable]
    public class CameraViewComposite
    {
        [Min(0.0001f)] public float resolutionPerMeter = 100f;
        [Min(0.0001f)] public float perspectiveDistance = 1f;
        public Vector2 size = Vector2.one;
        public Camera targetCamera;
        public Rect blitRect = new(0f, 0f, 1f, 1f);
        
        public Vector2Int RenderSize
        {
            get
            {
                var width = Mathf.Max(1, Mathf.RoundToInt(Mathf.Abs(size.x) * resolutionPerMeter));
                var height = Mathf.Max(1, Mathf.RoundToInt(Mathf.Abs(size.y) * resolutionPerMeter));
                return new Vector2Int(width, height);
            }
        }
    }

    [SerializeField] private SpoutSender targetSender;
    [SerializeField] private MeshRenderer targetQuadRenderer;
    [SerializeField] private CameraViewComposite[] targets;
    [SerializeField] private Vector2Int outputSize = new(1920, 1080);

    private readonly List<CaptureRegistration> _registrations = new();
    private RenderTexture _compositeTexture;
    private bool _hasClearedThisFrame;

    private sealed class CaptureRegistration
    {
        public CameraViewComposite Target;
        public Action<RenderTargetIdentifier, CommandBuffer> Action;
    }

    private void OnEnable()
    {
        EnsureCompositeTexture();
        RegisterCaptureActions();
        ApplyTargetCameraSettings();
        ConfigureSender();
    }

    private void LateUpdate()
    {
        _hasClearedThisFrame = false;
        EnsureCompositeTexture();
        ApplyTargetCameraSettings();
        ConfigureSender();
    }

    private void OnDisable()
    {
        UnregisterCaptureActions();

        if (targetSender && targetSender.sourceTexture == _compositeTexture)
            targetSender.sourceTexture = null;

        ReleaseCompositeTexture();
    }

    private void RegisterCaptureActions()
    {
        UnregisterCaptureActions();

        if (targets == null)
            return;

        foreach (var target in targets)
        {
            if (target == null || !target.targetCamera)
                continue;

            var capturedTarget = target;
            var action = new Action<RenderTargetIdentifier, CommandBuffer>(
                (source, commandBuffer) => CaptureCamera(capturedTarget, source, commandBuffer));

            CameraCaptureBridge.AddCaptureAction(target.targetCamera, action);
            _registrations.Add(new CaptureRegistration { Target = target, Action = action });
        }
    }

    private void ApplyTargetCameraSettings()
    {
        if (targets == null)
            return;

        foreach (var target in targets)
        {
            if (target == null || !target.targetCamera ||
                target.size.x <= 0f || target.size.y <= 0f)
                continue;

            var targetCamera = target.targetCamera;
            targetCamera.aspect = target.size.x / target.size.y;

            if (targetCamera.orthographic)
            {
                // The physical composite area is centered on the camera's view plane.
                targetCamera.orthographicSize = Mathf.Max(target.size.y * 0.5f, 0.01f);
                continue;
            }

            // For perspective cameras, size is the physical width/height of the
            // view rectangle at perspectiveDistance meters from the camera.
            var distance = Mathf.Max(target.perspectiveDistance, 0.0001f);
            var halfHeight = Mathf.Max(target.size.y * 0.5f, 0.0001f);
            targetCamera.fieldOfView = 2f * Mathf.Atan(halfHeight / distance) * Mathf.Rad2Deg;
        }
    }

    private void UnregisterCaptureActions()
    {
        foreach (var registration in _registrations)
        {
            if (registration.Target?.targetCamera)
                CameraCaptureBridge.RemoveCaptureAction(registration.Target.targetCamera, registration.Action);
        }

        _registrations.Clear();
    }

    private void CaptureCamera(CameraViewComposite target, RenderTargetIdentifier source, CommandBuffer commandBuffer)
    {
        if (target == null || !target.targetCamera || !_compositeTexture)
            return;

        if (!_hasClearedThisFrame)
        {
            commandBuffer.SetRenderTarget(_compositeTexture);
            commandBuffer.ClearRenderTarget(false, true, Color.clear);
            _hasClearedThisFrame = true;
        }

        var sourceRect = NormalizeRect(target.targetCamera.rect);
        var destinationNormalizedRect = target.blitRect;

        if (destinationNormalizedRect.width <= 0 || destinationNormalizedRect.height <= 0)
            destinationNormalizedRect = sourceRect;

        destinationNormalizedRect = NormalizeRect(destinationNormalizedRect);
        var destinationRect = new Rect(
            destinationNormalizedRect.x * _compositeTexture.width,
            destinationNormalizedRect.y * _compositeTexture.height,
            destinationNormalizedRect.width * _compositeTexture.width,
            destinationNormalizedRect.height * _compositeTexture.height);

        // CameraCaptureBridge gives us the camera color target before overlay UI.
        // Crop the camera's current viewport and place it in the target blitRect.
        commandBuffer.SetRenderTarget(_compositeTexture);
        commandBuffer.SetViewport(destinationRect);
        commandBuffer.Blit(
            source,
            BuiltinRenderTextureType.CurrentActive,
            new Vector2(sourceRect.width, sourceRect.height),
            new Vector2(sourceRect.x, sourceRect.y));
    }

    private static Rect NormalizeRect(Rect rect)
    {
        var minX = Mathf.Clamp01(rect.x);
        var minY = Mathf.Clamp01(rect.y);
        var maxX = Mathf.Clamp01(rect.x + rect.width);
        var maxY = Mathf.Clamp01(rect.y + rect.height);
        return Rect.MinMaxRect(minX, minY, maxX, maxY);
    }

    private void ConfigureSender()
    {
        if (!targetSender || !_compositeTexture)
            return;

        targetSender.captureMethod = CaptureMethod.Texture;
        targetSender.sourceTexture = _compositeTexture;
        
        if(targetQuadRenderer)
            targetQuadRenderer.material.mainTexture = _compositeTexture;
    }

    private void EnsureCompositeTexture()
    {
        var width = outputSize.x > 0 ? outputSize.x : Screen.width;
        var height = outputSize.y > 0 ? outputSize.y : Screen.height;

        if (width <= 0)
            width = 1920;
        if (height <= 0)
            height = 1080;

        if (_compositeTexture &&
            (_compositeTexture.width != width || _compositeTexture.height != height))
        {
            ReleaseCompositeTexture();
        }

        if (_compositeTexture)
            return;

        _compositeTexture = new RenderTexture(width, height, 0, RenderTextureFormat.Default)
        {
            name = "Spout Camera Composite",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp,
            useMipMap = false,
            autoGenerateMips = false,
            hideFlags = HideFlags.DontSave
        };
        _compositeTexture.Create();
    }

    private void ReleaseCompositeTexture()
    {
        if (!_compositeTexture)
            return;

        _compositeTexture.Release();
        if (Application.isPlaying)
            Destroy(_compositeTexture);
        else
            DestroyImmediate(_compositeTexture);

        _compositeTexture = null;
    }
}
