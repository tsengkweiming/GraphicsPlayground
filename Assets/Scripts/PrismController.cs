using UnityEngine;

[System.Serializable]
public class PrismControllerParam : ShaderControllerParam<PrismControllerParam>
{
    [Range(0, 6)] public float patternMode;
    [Range(0, 1)] public float patternBlend;
    [Range(0, 4)] public float repeatScale;
    [Range(0, 2)] public float warpStrength;
    [Range(0, 5)] public float prismRadius;
    [Range(0, 1.5f)] public float stepScale;
    [Range(0, 4)] public float colorSpread;
    [Range(0, 5)] public float exposure;
    
    public override void CopyFrom(PrismControllerParam other)
    {
        if (other == null)
        {
            return;
        }

        patternMode = other.patternMode;
        patternBlend = other.patternBlend;
        repeatScale = other.repeatScale;
        warpStrength = other.warpStrength;
        prismRadius = other.prismRadius;
        stepScale = other.stepScale;
        colorSpread = other.colorSpread;
        exposure = other.exposure;
    }

    public override void MoveTowards(PrismControllerParam target, float t)
    {
        if (target == null)
        {
            return;
        }

        patternMode = LerpValue(patternMode, target.patternMode, t);
        patternBlend = LerpValue(patternBlend, target.patternBlend, t);
        repeatScale = LerpValue(repeatScale, target.repeatScale, t);
        warpStrength = LerpValue(warpStrength, target.warpStrength, t);
        prismRadius = LerpValue(prismRadius, target.prismRadius, t);
        stepScale = LerpValue(stepScale, target.stepScale, t);
        colorSpread = LerpValue(colorSpread, target.colorSpread, t);
        exposure = LerpValue(exposure, target.exposure, t);
    }

    public override bool Approximately(PrismControllerParam other)
    {
        if (other == null)
        {
            return false;
        }

        return ApproximatelyValue(patternMode, other.patternMode)
               && ApproximatelyValue(patternBlend, other.patternBlend)
               && ApproximatelyValue(repeatScale, other.repeatScale)
               && ApproximatelyValue(warpStrength, other.warpStrength)
               && ApproximatelyValue(prismRadius, other.prismRadius)
               && ApproximatelyValue(stepScale, other.stepScale)
               && ApproximatelyValue(colorSpread, other.colorSpread)
               && ApproximatelyValue(exposure, other.exposure);
    }
}

public class PrismController : ShaderController
{
    [SerializeField] private PrismControllerParam _param;

    private static readonly int PatternModeId = Shader.PropertyToID("_ShapeMode");
    private static readonly int PatternBlendId = Shader.PropertyToID("_PatternBlend");
    private static readonly int ScaleId = Shader.PropertyToID("_RepeatScale");
    private static readonly int WarpId = Shader.PropertyToID("_WarpStrength");
    private static readonly int PrismRadiusId = Shader.PropertyToID("_PrismRadius");
    private static readonly int StepScaleId = Shader.PropertyToID("_StepScale");
    private static readonly int ColorSpreadId = Shader.PropertyToID("_ColorSpread");
    private static readonly int ExposureId = Shader.PropertyToID("_Exposure");

    private readonly PrismControllerParam _currentParam = new PrismControllerParam();
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

    private void ApplyParam(PrismControllerParam param)
    {
        if (!_material)
        {
            return;
        }

        _material.SetFloat(PatternModeId, param.patternMode);
        _material.SetFloat(PatternBlendId, param.patternBlend);
        _material.SetFloat(ScaleId, param.repeatScale);
        _material.SetFloat(WarpId, param.warpStrength);
        _material.SetFloat(PrismRadiusId, param.prismRadius);
        _material.SetFloat(StepScaleId, param.stepScale);
        _material.SetFloat(ColorSpreadId, param.colorSpread);
        _material.SetFloat(ExposureId, param.exposure);
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
