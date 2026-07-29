using System.Collections.Generic;
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
public class TextGIParam : ShaderControllerParam<TextGIParam>
{
    public LightType LightType = LightType.Text;
    [Range(1, 30)] public int MaxRay;
    public int MaxStep;
    [Range(0, 3000)] public int MaxDist;
    public float AttenuationPower;
    [Range(0, 40)] public int ObjectCount;
    [Range(-3, 75)] public float EdgeThickness = 2.0f;
    public Vector2 StickSize = new(40, 5);
    public float OrbitAngularSpeed;
    public float RotateXMultiplier;
    public float RotateYMultiplier;
    public float textRotationMax;
    public float textRotationSpeed;
    public float textRotationXMax;
    public float textRotationXSpeed;
    public float textPerspective;
    public float textPositionMax;
    public float textPositionSpeed;

    public override void CopyFrom(TextGIParam other)
    {
        if (other == null)
        {
            return;
        }

        LightType = other.LightType;
        MaxRay = other.MaxRay;
        MaxStep = other.MaxStep;
        MaxDist = other.MaxDist;
        AttenuationPower = other.AttenuationPower;
        ObjectCount = other.ObjectCount;
        EdgeThickness = other.EdgeThickness;
        StickSize = other.StickSize;
        OrbitAngularSpeed = other.OrbitAngularSpeed;
        RotateXMultiplier = other.RotateXMultiplier;
        RotateYMultiplier = other.RotateYMultiplier;
        textRotationMax = other.textRotationMax;
        textRotationSpeed = other.textRotationSpeed;
        textRotationXMax = other.textRotationXMax;
        textRotationXSpeed = other.textRotationXSpeed;
        textPerspective = other.textPerspective;
        textPositionMax = other.textPositionMax;
        textPositionSpeed = other.textPositionSpeed;
    }

    public override void MoveTowards(TextGIParam target, float t)
    {
        if (target == null)
        {
            return;
        }

        LightType = LerpValue(LightType, target.LightType, t);
        MaxRay = LerpValue(MaxRay, target.MaxRay, t);
        MaxStep = LerpValue(MaxStep, target.MaxStep, t);
        MaxDist = LerpValue(MaxDist, target.MaxDist, t);
        AttenuationPower = LerpValue(AttenuationPower, target.AttenuationPower, t);
        ObjectCount = LerpValue(ObjectCount, target.ObjectCount, t);
        EdgeThickness = LerpValue(EdgeThickness, target.EdgeThickness, t);
        StickSize = LerpValue(StickSize, target.StickSize, t);
        OrbitAngularSpeed = LerpValue(OrbitAngularSpeed, target.OrbitAngularSpeed, t);
        RotateXMultiplier = LerpValue(RotateXMultiplier, target.RotateXMultiplier, t);
        RotateYMultiplier = LerpValue(RotateYMultiplier, target.RotateYMultiplier, t);
        textRotationMax = LerpValue(textRotationMax, target.textRotationMax, t);
        textRotationSpeed = LerpValue(textRotationSpeed, target.textRotationSpeed, t);
        textRotationXMax = LerpValue(textRotationXMax, target.textRotationXMax, t);
        textRotationXSpeed = LerpValue(textRotationXSpeed, target.textRotationXSpeed, t);
        textPerspective = LerpValue(textPerspective, target.textPerspective, t);
        textPositionMax = LerpValue(textPositionMax, target.textPositionMax, t);
        textPositionSpeed = LerpValue(textPositionSpeed, target.textPositionSpeed, t);
    }

    public override bool Approximately(TextGIParam other)
    {
        if (other == null)
        {
            return false;
        }

        return ApproximatelyValue(LightType, other.LightType)
            && ApproximatelyValue(MaxRay, other.MaxRay)
            && ApproximatelyValue(MaxStep, other.MaxStep)
            && ApproximatelyValue(MaxDist, other.MaxDist)
            && ApproximatelyValue(AttenuationPower, other.AttenuationPower)
            && ApproximatelyValue(ObjectCount, other.ObjectCount)
            && ApproximatelyValue(EdgeThickness, other.EdgeThickness)
            && ApproximatelyValue(StickSize, other.StickSize)
            && ApproximatelyValue(OrbitAngularSpeed, other.OrbitAngularSpeed)
            && ApproximatelyValue(RotateXMultiplier, other.RotateXMultiplier)
            && ApproximatelyValue(RotateYMultiplier, other.RotateYMultiplier)
            && ApproximatelyValue(textRotationMax, other.textRotationMax)
            && ApproximatelyValue(textRotationSpeed, other.textRotationSpeed)
            && ApproximatelyValue(textRotationXMax, other.textRotationXMax)
            && ApproximatelyValue(textRotationXSpeed, other.textRotationXSpeed)
            && ApproximatelyValue(textPerspective, other.textPerspective)
            && ApproximatelyValue(textPositionMax, other.textPositionMax)
            && ApproximatelyValue(textPositionSpeed, other.textPositionSpeed);
    }
}

[RequireComponent(typeof(Camera))]
public class ProceduralTextGIController : MonoBehaviour
{
    private static readonly Dictionary<Camera, ProceduralTextGIController> ControllersByCamera = new();

    [SerializeField] private ComputeShader  _lightCompute;
    [SerializeField] private Shader         _toneShader;
    [FormerlySerializedAs("_lightGIParam")]
    [SerializeField] private TextGIParam   _textGIParam = new ();
    [SerializeField] private float _paramInterpolationSpeed = 2f;
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
    private readonly TextGIParam _currentTextGIParam = new();
    
    public TextGIParam TextGIParam {get => _textGIParam; set  => _textGIParam = value; }
    
    public static bool TryGetForCamera(Camera camera, out ProceduralTextGIController controller)
    {
        if (camera != null &&
            ControllersByCamera.TryGetValue(camera, out controller) &&
            controller != null &&
            controller.isActiveAndEnabled)
        {
            return true;
        }

        controller = null;
        return false;
    }

    private void OnEnable()
    {
        RegisterCamera();
        InitializeParam();
    }

    void Start()
    {
        InitializeParam();
        EnsureRuntimeResources();
        SyncTextBuffers();
    }

    // Update is called once per frame
    void Update()
    {
        TickParam(Time.deltaTime);
    }

    private void OnDisable()
    {
        UnregisterCamera();
    }

    private void OnDestroy()
    {
        UnregisterCamera();
        ReleaseRTs();
        if (_toneMappingMaterial != null) Destroy(_toneMappingMaterial);
        ReleaseTextBuffers();
    }

    private void OnValidate()
    {
        _paramInterpolationSpeed = Mathf.Max(0f, _paramInterpolationSpeed);
    }

    private void InitializeParam()
    {
        if (_textGIParam == null)
        {
            _textGIParam = new TextGIParam();
        }

        _currentTextGIParam.CopyFrom(_textGIParam);
    }

    private void TickParam(float deltaTime)
    {
        if (_textGIParam == null)
        {
            return;
        }

        if (_paramInterpolationSpeed <= 0f)
        {
            _currentTextGIParam.CopyFrom(_textGIParam);
        }
        else if (!_currentTextGIParam.Approximately(_textGIParam))
        {
            _currentTextGIParam.MoveTowards(_textGIParam, _paramInterpolationSpeed * deltaTime);
        }
    }

    private void RegisterCamera()
    {
        if (_camera == null) _camera = GetComponent<Camera>();
        if (_camera != null) ControllersByCamera[_camera] = this;
    }

    private void UnregisterCamera()
    {
        if (_camera == null) return;
        if (ControllersByCamera.TryGetValue(_camera, out var controller) && controller == this)
        {
            ControllersByCamera.Remove(_camera);
        }
    }

    private bool EnsureRuntimeResources()
    {
        RegisterCamera();
        if (_camera == null || _lightCompute == null) return false;

        if (_kernel < 0)
        {
            _kernel = _lightCompute.FindKernel("CSMain");
        }

        if (_toneShader != null && _toneMappingMaterial == null)
        {
            _toneMappingMaterial = new Material(_toneShader);
        }

        int w = _camera.pixelWidth;
        int h = _camera.pixelHeight;
        if (w <= 0 || h <= 0) return false;

        if (_rts[0] == null || _rts[0].width != w || _rts[0].height != h)
        {
            ReleaseRTs();
            InitRTs(w, h);
            _frameCount = 0;
        }

        return _rts[0] != null && _rts[1] != null;
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

    public bool RenderInto(CommandBuffer cmd, RTHandle cameraColorTarget)
    {
        if (cmd == null || cameraColorTarget == null) return false;
        if (!EnsureRuntimeResources()) return false;

        int w = _camera.pixelWidth;
        int h = _camera.pixelHeight;

        SyncTextBuffers();
        TextGIParam param = _currentTextGIParam;
        
        // Dispatch compute shader.
        _lightCompute.SetTexture(_kernel, "_Result",     _rts[_current]);
        _lightCompute.SetTexture(_kernel, "_PrevFrame",  _rts[1 - _current]);
        _lightCompute.SetVector("_Resolution", new Vector2(w, h));
        _lightCompute.SetFloat ("_Time",          Time.time);
        _lightCompute.SetInt   ("_Frame",         _frameCount++);
        _lightCompute.SetInt   ("_LightType",     (int)param.LightType);
        _lightCompute.SetInt   ("_MaxRay",        param.MaxRay);
        _lightCompute.SetInt   ("_MaxStep",       param.MaxStep);
        _lightCompute.SetInt   ("_MaxDist",       param.MaxDist);
        _lightCompute.SetInt   ("_ObjectCount",      param.ObjectCount);
        _lightCompute.SetFloat ("_AttenuationPower",  param.AttenuationPower);
        _lightCompute.SetFloat ("_EdgeThickness",     param.EdgeThickness);
        _lightCompute.SetFloat ("_OrbitAngularSpeed", param.OrbitAngularSpeed);
        _lightCompute.SetFloat ("_RotateXMultiplier", param.RotateXMultiplier);
        _lightCompute.SetFloat ("_RotateYMultiplier", param.RotateYMultiplier);
        _lightCompute.SetFloat ("_TextRotationMax", param.textRotationMax);
        _lightCompute.SetFloat ("_TextRotationSpeed", param.textRotationSpeed);
        _lightCompute.SetFloat ("_TextRotationXMax", param.textRotationXMax);
        _lightCompute.SetFloat ("_TextRotationXSpeed", param.textRotationXSpeed);
        _lightCompute.SetFloat ("_TextPerspective", param.textPerspective);
        _lightCompute.SetFloat ("_TextPositionMax", param.textPositionMax);
        _lightCompute.SetFloat ("_TextPositionSpeed", param.textPositionSpeed);
        _lightCompute.SetVector("_StickSize", param.StickSize);
        _lightCompute.SetInt   ("_DotCount",       _dots?.Length ?? 0);
        _lightCompute.SetInt   ("_CharacterCount", _characters?.Length ?? 0);
        _lightCompute.SetInt   ("_TextCount",      _texts?.Length ?? 0);
        _lightCompute.SetBuffer(_kernel, "_DotBuffer", _dotBuffer);
        _lightCompute.SetBuffer(_kernel, "_CharacterBuffer", _characterBuffer);
        _lightCompute.SetBuffer(_kernel, "_TextBuffer", _textBuffer);

        int gx = Mathf.CeilToInt(w / 8f);
        int gy = Mathf.CeilToInt(h / 8f);
        _lightCompute.Dispatch(_kernel, gx, gy, 1);

        if (_toneMappingMaterial != null)
        {
            cmd.Blit(_rts[_current], cameraColorTarget.nameID, _toneMappingMaterial);
        }
        else
        {
            cmd.Blit(_rts[_current], cameraColorTarget.nameID);
        }

        // Swap ping-pong.
        _current = 1 - _current;
        return true;
    }

    // ─── RT helpers ───────────────────────────────────────────────────────────
    private void InitRTs(int w, int h)
    {
        for (int i = 0; i < 2; i++)
        {
            _rts[i] = new RenderTexture(w, h, 0, RenderTextureFormat.ARGB32)
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
