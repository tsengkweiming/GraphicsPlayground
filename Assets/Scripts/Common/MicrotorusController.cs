using UnityEngine;

namespace Common
{
[ExecuteAlways]
[RequireComponent(typeof(Renderer))]
public class MicrotorusController : EffectController
{
    [SerializeField] private float swipeSpeed = 1f;
    [SerializeField] private float recoverSpeed = 2f;
    [SerializeField] private float engageSpeed = 2f;

    private static readonly int DirSwitchId = Shader.PropertyToID("_DirSwitch");
    private static readonly int SwipeOffsetId = Shader.PropertyToID("_SwipeOffset");
    private static readonly int SwipeWarpId = Shader.PropertyToID("_SwipeWarp");

    private Vector2 _swipeOffset;
    private Vector2 _swipeWarp;
    private int _activeAxis;
    private bool _recovering;
    private double _lastEditorTime;

    protected override void OnEnable()
    {
        base.OnEnable();

        Material material = GetTargetMaterial(out _);
        _activeAxis = GetRequestedAxis(material);
        _swipeWarp = _activeAxis == 0 ? Vector2.right : Vector2.up;
        _recovering = false;

        _lastEditorTime = GetEditorTime();

#if UNITY_EDITOR
        UnityEditor.EditorApplication.update += EditorUpdate;
#endif
    }

    private void OnDisable()
    {
#if UNITY_EDITOR
        UnityEditor.EditorApplication.update -= EditorUpdate;
#endif
    }

    private void Update()
    {
        if (Application.isPlaying)
        {
            Tick(Time.deltaTime);
        }
    }

#if UNITY_EDITOR
    private void EditorUpdate()
    {
        if (Application.isPlaying)
        {
            return;
        }

        double editorTime = UnityEditor.EditorApplication.timeSinceStartup;
        float deltaTime = Mathf.Min((float)(editorTime - _lastEditorTime), 1f / 15f);
        _lastEditorTime = editorTime;

        Tick(deltaTime);
        UnityEditor.SceneView.RepaintAll();
    }
#endif

    protected override void Tick(float deltaTime)
    {
        if (_targetRenderer == null)
        {
            return;
        }

        Material material = GetTargetMaterial(out int index);
        if (material == null)
        {
            return;
        }

        int requestedAxis = GetRequestedAxis(material);

        if (requestedAxis != _activeAxis)
        {
            _recovering = true;
        }

        if (_recovering)
        {
            _swipeWarp.x = Mathf.MoveTowards(_swipeWarp.x, 0f, recoverSpeed * deltaTime);
            _swipeWarp.y = Mathf.MoveTowards(_swipeWarp.y, 0f, recoverSpeed * deltaTime);

            if (_swipeWarp.sqrMagnitude <= 0.0001f)
            {
                _swipeWarp = Vector2.zero;
                _activeAxis = requestedAxis;
                _recovering = false;
            }
        }
        else
        {
            if (_activeAxis == 0)
            {
                _swipeOffset.x += deltaTime * swipeSpeed;
                _swipeWarp.x = Mathf.MoveTowards(_swipeWarp.x, 1f, engageSpeed * deltaTime);
                _swipeWarp.y = Mathf.MoveTowards(_swipeWarp.y, 0f, recoverSpeed * deltaTime);
            }
            else
            {
                _swipeOffset.y += deltaTime * swipeSpeed;
                _swipeWarp.x = Mathf.MoveTowards(_swipeWarp.x, 0f, recoverSpeed * deltaTime);
                _swipeWarp.y = Mathf.MoveTowards(_swipeWarp.y, 1f, engageSpeed * deltaTime);
            }
        }

        _targetRenderer.GetPropertyBlock(_propertyBlock, index);
        _propertyBlock.SetVector(SwipeOffsetId, new Vector4(_swipeOffset.x, _swipeOffset.y, 0f, 0f));
        _propertyBlock.SetVector(SwipeWarpId, new Vector4(_swipeWarp.x, _swipeWarp.y, 0f, 0f));
        _targetRenderer.SetPropertyBlock(_propertyBlock, index);
    }

    private static int GetRequestedAxis(Material material)
    {
        if (!material || !material.HasProperty(DirSwitchId))
        {
            return 0;
        }

        return material.GetFloat(DirSwitchId) >= 0.5f ? 1 : 0;
    }

    private static double GetEditorTime()
    {
#if UNITY_EDITOR
        return UnityEditor.EditorApplication.timeSinceStartup;
#else
        return Time.timeAsDouble;
#endif
    }
}
}
