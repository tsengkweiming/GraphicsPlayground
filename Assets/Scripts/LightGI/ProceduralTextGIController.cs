using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

[System.Serializable]
public struct Dot2d
{
    public Vector2 Position;
    public float   Curvature;    // 0: straight, > 0: curvature
    public int     StartOfNext;
    public Color   Color;
};

[System.Serializable]
public struct Character
{
    public Dot2d[] Dots;
    public int     Id;        // order id of the text
    public Vector3 Position;  // do some boid?
    public Vector3 Velocity;
    public Vector3 Scale;
};

[System.Serializable]
public struct Text
{
    public Character[] Characters;
    public Vector3     Position;
    public Vector3     Velocity;
};
public class ProceduralTextGIController : MonoBehaviour
{
    [SerializeField] private ComputeShader  _lightCompute;
    [SerializeField] private Shader         _toneShader;
    [SerializeField] private LightGIParam _lightGIParam;
    [SerializeField] private Text[] _texts;
    private Text[] _lastTexts;
    private GraphicsBuffer _textBuffer;
    
    private Camera            _camera;
    private Material          _toneMappingMaterial;
    private RenderTexture[]   _rts        = new RenderTexture[2];
    private int               _current    = 0;
    private int               _frameCount = 0;
    private int               _kernel     = -1;
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        _camera               = GetComponent<Camera>();
        _toneMappingMaterial  = new Material(_toneShader);
        _kernel               = _lightCompute.FindKernel("CSMain");
        InitRTs(_camera.pixelWidth, _camera.pixelHeight);
    }

    // Update is called once per frame
    void Update()
    {
    }

    private void OnDestroy()
    {
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
        ReleaseRTs();
        if (_toneMappingMaterial != null) Destroy(_toneMappingMaterial);
        _textBuffer?.Release();
        _textBuffer = null;
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

        if (_lastTexts != _texts)
        {
            _textBuffer.Release();
            _textBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, _texts.Length, Marshal.SizeOf(typeof(Text)));
            _textBuffer.SetData(_texts);
            _lastTexts = _texts;
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
        _lightCompute.SetBuffer(_kernel, "_TextBuffer", _textBuffer);

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
