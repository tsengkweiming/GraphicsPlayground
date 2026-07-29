using UnityEngine;

[System.Serializable]
public class GyroidControllerParam : ShaderControllerParam<GyroidControllerParam>
{
    [Range(0, 4)] public float patternMode;
    [Range(0, 1)] public float shapeBlend;
    [Range(0, 12)] public float scale = 4;
    [Range(0, 2)] public float warp;
    public float thickness = 0.1f;
    public float twist;
    [Range(0, 4)] public float colorMode = 1;
    [Range(0.05f, 3)] public float colorFrequency = 1;
    [Range(0, 2)] public float colorContrast = 1;
    public float moveTime = 0.25f;

    public override void CopyFrom(GyroidControllerParam other)
    {
        if (other == null)
        {
            return;
        }

        patternMode = other.patternMode;
        shapeBlend = other.shapeBlend;
        scale = other.scale;
        warp = other.warp;
        thickness = other.thickness;
        twist = other.twist;
        colorMode = other.colorMode;
        colorFrequency = other.colorFrequency;
        colorContrast = other.colorContrast;
        moveTime = other.moveTime;
    }

    public override void MoveTowards(GyroidControllerParam target, float t)
    {
        if (target == null)
        {
            return;
        }

        patternMode = LerpValue(patternMode, target.patternMode, t);
        shapeBlend = LerpValue(shapeBlend, target.shapeBlend, t);
        scale = LerpValue(scale, target.scale, t);
        warp = LerpValue(warp, target.warp, t);
        thickness = LerpValue(thickness, target.thickness, t);
        twist = LerpValue(twist, target.twist, t);
        colorMode = LerpValue(colorMode, target.colorMode, t);
        colorFrequency = LerpValue(colorFrequency, target.colorFrequency, t);
        colorContrast = LerpValue(colorContrast, target.colorContrast, t);
        moveTime = LerpValue(moveTime, target.moveTime, t);
    }

    public override bool Approximately(GyroidControllerParam other)
    {
        if (other == null)
        {
            return false;
        }

        return ApproximatelyValue(patternMode, other.patternMode)
            && ApproximatelyValue(shapeBlend, other.shapeBlend)
            && ApproximatelyValue(scale, other.scale)
            && ApproximatelyValue(warp, other.warp)
            && ApproximatelyValue(thickness, other.thickness)
            && ApproximatelyValue(twist, other.twist)
            && ApproximatelyValue(colorMode, other.colorMode)
            && ApproximatelyValue(colorFrequency, other.colorFrequency)
            && ApproximatelyValue(colorContrast, other.colorContrast)
            && ApproximatelyValue(moveTime, other.moveTime);
    }
}

public class GyroidController : ShaderController
{
    [SerializeField] private GyroidControllerParam _param;

    private static readonly int PatternModeId = Shader.PropertyToID("_PatternMode");
    private static readonly int ShapeBlendId = Shader.PropertyToID("_ShapeBlend");
    private static readonly int ScaleId = Shader.PropertyToID("_Scale");
    private static readonly int WarpId = Shader.PropertyToID("_Warp");
    private static readonly int ThicknessId = Shader.PropertyToID("_Thickness");
    private static readonly int TwistId = Shader.PropertyToID("_Twist");
    private static readonly int ColorModeId = Shader.PropertyToID("_ColorMode");
    private static readonly int ColorFrequencyId = Shader.PropertyToID("_ColorFrequency");
    private static readonly int ColorContrastId = Shader.PropertyToID("_ColorContrast");
    private static readonly int MoveTimeId = Shader.PropertyToID("_MoveTime");

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

        _material.SetFloat(PatternModeId, param.patternMode);
        _material.SetFloat(ShapeBlendId, param.shapeBlend);
        _material.SetFloat(ScaleId, param.scale);
        _material.SetFloat(WarpId, param.warp);
        _material.SetFloat(ThicknessId, param.thickness);
        _material.SetFloat(TwistId, param.twist);
        _material.SetFloat(ColorModeId, param.colorMode);
        _material.SetFloat(ColorFrequencyId, param.colorFrequency);
        _material.SetFloat(ColorContrastId, param.colorContrast);
        _material.SetFloat(MoveTimeId, param.moveTime);
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
