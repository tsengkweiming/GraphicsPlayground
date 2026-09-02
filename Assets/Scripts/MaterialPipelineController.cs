using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Presenter for a chain of ShaderControllers.
///
/// Input precedence is:
/// 1. Source assigned by code,
/// 2. sourceTexture assigned in the Inspector,
/// 3. CameraResultSource.Result,
/// 4. sourceCamera.targetTexture.
/// </summary>
public class MaterialPipelineController : MonoBehaviour
{
    [System.Serializable]
    public class MaterialPipeline
    {
        public ShaderController controller;
        public string textureName;
        public bool byPass;
    }

    [SerializeField] private List<MaterialPipeline> materialPipelines;
    [SerializeField] private Renderer outputRenderer;
    [SerializeField] private string outputPropertyName = "_MainTex";

    [Header("Input")]
    [SerializeField] private Texture sourceTexture;
    [SerializeField] private CameraResultSource cameraResultSource;
    [SerializeField] private Camera sourceCamera;

    private Texture _sourceOverride;
    private MaterialPipelineModel _model;
    private MaterialPipelineView _view;

    /// <summary>
    /// Runtime input override. Assigning a camera target texture here is also
    /// supported: pipeline.Source = camera.targetTexture.
    /// </summary>
    public Texture Source
    {
        get => _sourceOverride;
        set => _sourceOverride = value;
    }

    public Texture Result => _model?.Result;

    private void OnEnable()
    {
        if (!outputRenderer)
            outputRenderer = GetComponent<Renderer>();

        RebuildMvp();
    }

    void Update()
    {
        if (_model == null || _view == null)
            RebuildMvp();

        _model.SetSource(ResolveSource());
        _model.Execute();
        _view.Present(_model.Result);
    }

    private Texture ResolveSource()
    {
        if (_sourceOverride)
            return _sourceOverride;

        if (sourceTexture)
            return sourceTexture;

        if (cameraResultSource && cameraResultSource.Result)
            return cameraResultSource.Result;

        return sourceCamera ? sourceCamera.targetTexture : null;
    }

    private void RebuildMvp()
    {
        _model = new MaterialPipelineModel(materialPipelines);
        _view = new MaterialPipelineView(outputRenderer, outputPropertyName);
    }
}
