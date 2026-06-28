using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

[System.Serializable]
[StructLayout(LayoutKind.Sequential)]
public struct Dot2d
{
    public Vector2 Position;
    public float   Curvature;    // 0: straight, > 0: curvature
    public int     StartOfNext;
    public Color   Color;
};

[System.Serializable]
[StructLayout(LayoutKind.Sequential)]
public struct Character
{
    public int     DotOffset;    // first index into _DotBuffer
    public int     DotCount;     // how many dots this character owns
    public Vector3 Position;     // do some boid?
    // public Vector3 Velocity;
    public Vector3 Scale;
};

[System.Serializable]
[StructLayout(LayoutKind.Sequential)]
public struct Text
{
    public int     CharOffset;   // first index into _CharacterBuffer
    public int     CharCount;
    public Vector3 Position;
    // public Vector3 Velocity;
};


[System.Serializable]
public class TextGIParam
{
    public LightType LightType = LightType.Text;
    [Range(1,30)] public int MaxRay;
    public int MaxStep;
    [Range(0,3000)] public int MaxDist;
    public float AttenuationPower;
    [Range(0,40)] public int ObjectCount;
    [Range(-3,75)] public float EdgeThickness = 2.0f;
    public Vector2 StickSize = new (40, 5);
    public float OrbitAngularSpeed;
    public float RotateXMultiplier;
    public float RotateYMultiplier;
}

[RequireComponent(typeof(Camera))]
public class ProceduralTextGIController : MonoBehaviour
{
    [SerializeField] private ComputeShader  _lightCompute;
    [SerializeField] private Shader         _toneShader;
    [FormerlySerializedAs("_lightGIParam")]
    [SerializeField] private TextGIParam   _textGIParam = new ();
    [SerializeField] private Dot2d[] _dots;
    [SerializeField] private Character[] _characters;
    [SerializeField] private Text[] _texts;

    private static readonly Dot2d[] EmptyDots = { default };
    private static readonly Character[] EmptyCharacters = { default };
    private static readonly Text[] EmptyTexts = { default };

    private Dot2d[] _lastDots;
    private Character[] _lastCharacters;
    private Text[] _lastTexts;
    
    private GraphicsBuffer _dotBuffer;
    private GraphicsBuffer _characterBuffer;
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
        if (_toneShader != null) _toneMappingMaterial  = new Material(_toneShader);
        if (_lightCompute != null) _kernel = _lightCompute.FindKernel("CSMain");
        InitRTs(_camera.pixelWidth, _camera.pixelHeight);
        SyncTextBuffers();
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
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
        ReleaseTextBuffers();
    }

    private static bool EnsureBuffer(ref GraphicsBuffer buffer, int count, int stride)
    {
        if (buffer != null && buffer.count == count && buffer.stride == stride) return false;

        buffer?.Release();
        buffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, count, stride);
        return true;
    }

    private void SyncTextBuffers()
    {
        Dot2d[]     dots       = _dots       != null && _dots.Length       > 0 ? _dots       : EmptyDots;
        Character[] characters = _characters != null && _characters.Length > 0 ? _characters : EmptyCharacters;
        Text[]      texts      = _texts      != null && _texts.Length      > 0 ? _texts      : EmptyTexts;

        bool resized = false;
        resized |= EnsureBuffer(ref _dotBuffer,       dots.Length,       Marshal.SizeOf(typeof(Dot2d)));
        resized |= EnsureBuffer(ref _characterBuffer, characters.Length, Marshal.SizeOf(typeof(Character)));
        resized |= EnsureBuffer(ref _textBuffer,      texts.Length,      Marshal.SizeOf(typeof(Text)));

        bool dataUpdated = false;
        dataUpdated |= !ArrayUtility.Equals(_lastDots,       dots);
        dataUpdated |= !ArrayUtility.Equals(_lastCharacters, characters);
        dataUpdated |= !ArrayUtility.Equals(_lastTexts,      texts);
        
        bool needUpdate = resized || dataUpdated;
        if (needUpdate)
        {
            _dotBuffer.SetData(dots);
            _characterBuffer.SetData(characters);
            _textBuffer.SetData(texts);
            // Deep-copy so _last isn't the same reference as the live array
            _lastDots       = (Dot2d[])     dots.Clone();
            _lastCharacters = (Character[]) characters.Clone();
            _lastTexts      = (Text[])      texts.Clone();
        }
    }

    private void ReleaseTextBuffers()
    {
        _dotBuffer?.Release();
        _dotBuffer = null;
        _characterBuffer?.Release();
        _characterBuffer = null;
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

        SyncTextBuffers();
        
        // Dispatch compute shader.
        _lightCompute.SetTexture(_kernel, "_Result",     _rts[_current]);
        _lightCompute.SetTexture(_kernel, "_PrevFrame",  _rts[1 - _current]);
        _lightCompute.SetVector("_Resolution", new Vector2(w, h));
        _lightCompute.SetFloat ("_Time",          Time.time);
        _lightCompute.SetInt   ("_Frame",         _frameCount++);
        _lightCompute.SetInt   ("_LightType",     (int)_textGIParam.LightType);
        _lightCompute.SetInt   ("_MaxRay",        _textGIParam.MaxRay);
        _lightCompute.SetInt   ("_MaxStep",       _textGIParam.MaxStep);
        _lightCompute.SetInt   ("_MaxDist",       _textGIParam.MaxDist);
        _lightCompute.SetInt   ("_ObjectCount",      _textGIParam.ObjectCount);
        _lightCompute.SetFloat ("_AttenuationPower",  _textGIParam.AttenuationPower);
        _lightCompute.SetFloat ("_EdgeThickness",     _textGIParam.EdgeThickness);
        _lightCompute.SetFloat ("_OrbitAngularSpeed", _textGIParam.OrbitAngularSpeed);
        _lightCompute.SetFloat ("_RotateXMultiplier", _textGIParam.RotateXMultiplier);
        _lightCompute.SetFloat ("_RotateYMultiplier", _textGIParam.RotateYMultiplier);
        _lightCompute.SetVector("_StickSize", _textGIParam.StickSize);
        _lightCompute.SetInt   ("_DotCount",       _dots?.Length ?? 0);
        _lightCompute.SetInt   ("_CharacterCount", _characters?.Length ?? 0);
        _lightCompute.SetInt   ("_TextCount",      _texts?.Length ?? 0);
        _lightCompute.SetBuffer(_kernel, "_DotBuffer", _dotBuffer);
        _lightCompute.SetBuffer(_kernel, "_CharacterBuffer", _characterBuffer);
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
