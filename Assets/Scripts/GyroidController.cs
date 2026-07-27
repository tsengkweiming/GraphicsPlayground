using UnityEngine;

[System.Serializable]
public class GyroidControllerParam
{
    [Range(0, 4)] public float PatternMode;
    [Range(0, 1)] public float ShapeBlend;
    [Range(0, 12)] public float Scale = 4;
    [Range(0, 2)] public float Warp;
    public float Thickness = 0.1f;
    public float Twist;
    [Range(0, 4)] public float ColorMode = 1;
    [Range(0.05f, 3)] public float ColorFrequency = 1;
    [Range(0, 2)] public float ColorContrast = 1;

    public void CopyFrom(GyroidControllerParam other)
    {
        if (other == null)
        {
            return;
        }

        PatternMode = other.PatternMode;
        ShapeBlend = other.ShapeBlend;
        Scale = other.Scale;
        Warp = other.Warp;
        Thickness = other.Thickness;
        Twist = other.Twist;
        ColorMode = other.ColorMode;
        ColorFrequency = other.ColorFrequency;
        ColorContrast = other.ColorContrast;
    }

    public void MoveTowards(GyroidControllerParam target, float maxDelta)
    {
        if (target == null)
        {
            return;
        }

        PatternMode = Mathf.MoveTowards(PatternMode, target.PatternMode, maxDelta);
        ShapeBlend = Mathf.MoveTowards(ShapeBlend, target.ShapeBlend, maxDelta);
        Scale = Mathf.MoveTowards(Scale, target.Scale, maxDelta);
        Warp = Mathf.MoveTowards(Warp, target.Warp, maxDelta);
        Thickness = Mathf.MoveTowards(Thickness, target.Thickness, maxDelta);
        Twist = Mathf.MoveTowards(Twist, target.Twist, maxDelta);
        ColorMode = Mathf.MoveTowards(ColorMode, target.ColorMode, maxDelta);
        ColorFrequency = Mathf.MoveTowards(ColorFrequency, target.ColorFrequency, maxDelta);
        ColorContrast = Mathf.MoveTowards(ColorContrast, target.ColorContrast, maxDelta);
    }

    public bool Approximately(GyroidControllerParam other)
    {
        if (other == null)
        {
            return false;
        }

        return Mathf.Approximately(PatternMode, other.PatternMode)
            && Mathf.Approximately(ShapeBlend, other.ShapeBlend)
            && Mathf.Approximately(Scale, other.Scale)
            && Mathf.Approximately(Warp, other.Warp)
            && Mathf.Approximately(Thickness, other.Thickness)
            && Mathf.Approximately(Twist, other.Twist)
            && Mathf.Approximately(ColorMode, other.ColorMode)
            && Mathf.Approximately(ColorFrequency, other.ColorFrequency)
            && Mathf.Approximately(ColorContrast, other.ColorContrast);
    }
}

public class GyroidController : ShaderController
{
    [SerializeField] private GyroidControllerParam _param;
    [SerializeField] private float _interpolationSpeed = 2f;

    private static readonly int PatternModeId = Shader.PropertyToID("_PatternMode");
    private static readonly int ShapeBlendId = Shader.PropertyToID("_ShapeBlend");
    private static readonly int ScaleId = Shader.PropertyToID("_Scale");
    private static readonly int WarpId = Shader.PropertyToID("_Warp");
    private static readonly int ThicknessId = Shader.PropertyToID("_Thickness");
    private static readonly int TwistId = Shader.PropertyToID("_Twist");
    private static readonly int ColorModeId = Shader.PropertyToID("_ColorMode");
    private static readonly int ColorFrequencyId = Shader.PropertyToID("_ColorFrequency");
    private static readonly int ColorContrastId = Shader.PropertyToID("_ColorContrast");

    private readonly GyroidControllerParam _currentParam = new GyroidControllerParam();
    private double _lastEditorTime;

    protected override void Start()
    {
        base.Start();

        _currentParam.CopyFrom(_param);
        ApplyParam(_currentParam);
        _lastEditorTime = GetEditorTime();
    }

    private void OnEnable()
    {
        EnsureMaterial();

        _currentParam.CopyFrom(_param);
        ApplyParam(_currentParam);
        _lastEditorTime = GetEditorTime();
    }

    private void Update()
    {
        Tick(GetDeltaTime());
    }

    private void Tick(float deltaTime)
    {
        if (_param == null)
        {
            return;
        }

        EnsureMaterial();

        if (!_material)
        {
            return;
        }

        if (_interpolationSpeed <= 0f)
        {
            _currentParam.CopyFrom(_param);
        }
        else if (!_currentParam.Approximately(_param))
        {
            _currentParam.MoveTowards(_param, _interpolationSpeed * deltaTime);
        }

        ApplyParam(_currentParam);
    }

    private void ApplyParam(GyroidControllerParam param)
    {
        if (!_material)
        {
            return;
        }

        _material.SetFloat(PatternModeId, param.PatternMode);
        _material.SetFloat(ShapeBlendId, param.ShapeBlend);
        _material.SetFloat(ScaleId, param.Scale);
        _material.SetFloat(WarpId, param.Warp);
        _material.SetFloat(ThicknessId, param.Thickness);
        _material.SetFloat(TwistId, param.Twist);
        _material.SetFloat(ColorModeId, param.ColorMode);
        _material.SetFloat(ColorFrequencyId, param.ColorFrequency);
        _material.SetFloat(ColorContrastId, param.ColorContrast);
    }

    private float GetDeltaTime()
    {
        if (Application.isPlaying)
        {
            return Time.deltaTime;
        }

        double editorTime = GetEditorTime();
        float deltaTime = Mathf.Min((float)(editorTime - _lastEditorTime), 1f / 15f);
        _lastEditorTime = editorTime;
        return Mathf.Max(deltaTime, 0f);
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
