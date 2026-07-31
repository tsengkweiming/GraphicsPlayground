using System;
using System.Collections.Generic;
using UnityEngine;

public class MaterialPipelineController : MonoBehaviour
{
    [System.Serializable]
    public class MaterialPipeline
    {
        public ShaderController controller;
        public string textureName;
    }

    [SerializeField] private List<MaterialPipeline> materialPipelines;
    [SerializeField] private Renderer outputRenderer;
    [SerializeField] private string outputPropertyName = "_MainTex";
    private ShaderController _prevController;
    private void OnEnable()
    {
        if (outputRenderer == null)
            outputRenderer = GetComponent<Renderer>();

    }
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        foreach (var materialPipeline in materialPipelines)
        {
            var controller = materialPipeline.controller;
            var prevResult = _prevController?.RenderTexture;
            if(prevResult)
                controller.Source = prevResult;
            
            if(!String.IsNullOrEmpty(materialPipeline.textureName))
                controller.Material.SetTexture(materialPipeline.textureName, prevResult);
            _prevController = controller;
        }

        if (outputRenderer)
        {
            var lastIndex = materialPipelines.Count - 1;
            var finalOutput = materialPipelines[lastIndex].controller.RenderTexture;
            outputRenderer.material.SetTexture(outputPropertyName, finalOutput);
        }
    }
}
