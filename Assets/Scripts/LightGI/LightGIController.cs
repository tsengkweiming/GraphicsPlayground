using UnityEngine;
using UnityEngine.Rendering;

[System.Serializable]
public class LightGIParam
{
    public LightType LightType;
    [Range(1,20)] public int MaxRay;
    public int MaxStep;
    [Range(0,3000)] public int MaxDist;
    public float AttenuationPower;
    [Range(1,20)] public int ObjectCount;
    [Range(0,8)] public float EdgeThickness;
    public Vector2 StickSize = new (40, 5);
    public float OrbitAngularSpeed;
    public float RotateXMultiplier;
    public float RotateYMultiplier;
}

public enum LightType { Stick, Cube }

[RequireComponent(typeof(Camera))]
public class LightGIController : MonoBehaviour
{
    [SerializeField] private ComputeShader  _lightCompute;
    [SerializeField] private Shader         _toneShader;
    [SerializeField] private LightGIParam _lightGIParam;

    private Camera            _camera;
    private Material          _toneMappingMaterial;
    private RenderTexture[]   _rts        = new RenderTexture[2];
    private int               _current    = 0;
    private int               _frameCount = 0;
    private int               _kernel     = -1;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    void Start()
    {
        _camera               = GetComponent<Camera>();
        _toneMappingMaterial  = new Material(_toneShader);
        _kernel               = _lightCompute.FindKernel("CSMain");
        InitRTs(_camera.pixelWidth, _camera.pixelHeight);

        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    void OnDestroy()
    {
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
        ReleaseRTs();
        if (_toneMappingMaterial != null) Destroy(_toneMappingMaterial);
    }

    // ─── Per-frame render callback ────────────────────────────────────────────

    private void OnEndCameraRendering(ScriptableRenderContext ctx, Camera cam)
    {
        if (cam != _camera) return;

        int w = _camera.pixelWidth;
        int h = _camera.pixelHeight;

        // Recreate RTs on resize.
        if (_rts[0] == null || _rts[0].width != w || _rts[0].height != h)
        {
            ReleaseRTs();
            InitRTs(w, h);
            _frameCount = 0;
        }

        // Dispatch compute shader.
        _lightCompute.SetTexture(_kernel, "_Result",     _rts[_current]);
        _lightCompute.SetTexture(_kernel, "_PrevFrame", _rts[1 - _current]);
        _lightCompute.SetVector("_Resolution", new Vector2(w, h));
        _lightCompute.SetFloat ("_Time",       Time.time);
        _lightCompute.SetInt   ("_Frame",      _frameCount++);
        _lightCompute.SetInt   ("_LightType",      (int)_lightGIParam.LightType);
        _lightCompute.SetInt   ("_MaxRay",      _lightGIParam.MaxRay);
        _lightCompute.SetInt   ("_MaxStep",      _lightGIParam.MaxStep);
        _lightCompute.SetInt   ("_MaxDist",      _lightGIParam.MaxDist);
        _lightCompute.SetInt   ("_ObjectCount",      _lightGIParam.ObjectCount);
        _lightCompute.SetFloat ("_AttenuationPower",  _lightGIParam.AttenuationPower);
        _lightCompute.SetFloat ("_EdgeThickness",     _lightGIParam.EdgeThickness);
        _lightCompute.SetFloat ("_OrbitAngularSpeed", _lightGIParam.OrbitAngularSpeed);
        _lightCompute.SetFloat ("_RotateXMultiplier", _lightGIParam.RotateXMultiplier);
        _lightCompute.SetFloat ("_RotateYMultiplier", _lightGIParam.RotateYMultiplier);
        _lightCompute.SetVector("_StickSize", _lightGIParam.StickSize);

        int gx = Mathf.CeilToInt(w / 8f);
        int gy = Mathf.CeilToInt(h / 8f);
        _lightCompute.Dispatch(_kernel, gx, gy, 1);

        // Blit tone-mapped result onto the camera's output target.
        var cmd = CommandBufferPool.Get("LightGIBlit");
        cmd.Blit(_rts[_current], BuiltinRenderTextureType.CameraTarget, _toneMappingMaterial);
        ctx.ExecuteCommandBuffer(cmd);
        ctx.Submit();
        CommandBufferPool.Release(cmd);

        // Swap ping-pong.
        _current = 1 - _current;
    }

    // ─── RT helpers ───────────────────────────────────────────────────────────

    private void InitRTs(int w, int h)
    {
        for (int i = 0; i < 2; i++)
        {
            _rts[i] = new RenderTexture(w, h, 0, RenderTextureFormat.ARGBFloat)
            {
                enableRandomWrite = true,
                filterMode        = FilterMode.Bilinear,
                wrapMode          = TextureWrapMode.Clamp,
                name              = $"LightGI_rt{i}"
            };
            _rts[i].Create();
        }
    }

    private void ReleaseRTs()
    {
        for (int i = 0; i < 2; i++)
        {
            if (_rts[i] != null) { _rts[i].Release(); Destroy(_rts[i]); _rts[i] = null; }
        }
    }
}
