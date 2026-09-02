using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Rendering;

/// <summary>
/// Manages a chain of post-processing materials using CommandBuffer for efficiency.
/// Blits multiple materials in sequence: Input → Material 1 → Material 2 → ... → Output
///
/// Example: TextureBlendTransitions → PixelSort → Output
/// </summary>
public class MaterialPipelineManager : MonoBehaviour
{
    [System.Serializable]
    public class MaterialStage
    {
        public Material material;
        [TextArea(2, 3)]
        public string stageName = "Effect";
        public bool enabled = true;
    }

    [SerializeField] private Renderer outputRenderer;
    [SerializeField] private List<MaterialStage> materialPipeline = new List<MaterialStage>();

    [Header("Pipeline Settings")]
    [SerializeField] private int pipelineTextureWidth = 1024;
    [SerializeField] private int pipelineTextureHeight = 1024;
    [SerializeField] private RenderTextureFormat textureFormat = RenderTextureFormat.ARGB32;
    [SerializeField] private FilterMode filterMode = FilterMode.Bilinear;
    [SerializeField] private string outputPropertyName = "_MainTex";

    [Header("Debug")]
    [SerializeField] private bool logPipelineSteps = false;

    private RenderTexture[] pingPongTextures = new RenderTexture[2];
    private int currentReadTexture = 0;

    private void OnEnable()
    {
        if (outputRenderer == null)
            outputRenderer = GetComponent<Renderer>();

        CreatePingPongTextures();
    }

    private void OnDisable()
    {
        ReleasePingPongTextures();
    }

    private void CreatePingPongTextures()
    {
        ReleasePingPongTextures();

        for (int i = 0; i < 2; i++)
        {
            pingPongTextures[i] = new RenderTexture(pipelineTextureWidth, pipelineTextureHeight, 0, textureFormat)
            {
                filterMode = filterMode,
                wrapMode = TextureWrapMode.Clamp
            };
            pingPongTextures[i].Create();
        }

        if (logPipelineSteps)
            Debug.Log($"MaterialPipelineManager: Created ping-pong textures {pipelineTextureWidth}x{pipelineTextureHeight}");
    }

    private void ReleasePingPongTextures()
    {
        for (int i = 0; i < 2; i++)
        {
            if (pingPongTextures[i] != null)
            {
                pingPongTextures[i].Release();
                Destroy(pingPongTextures[i]);
                pingPongTextures[i] = null;
            }
        }
    }

    private void Update()
    {
        if (materialPipeline == null || materialPipeline.Count == 0 || outputRenderer == null)
            return;

        ExecutePipeline();
    }

    /// <summary>
    /// Execute all materials in sequence using CommandBuffer
    /// </summary>
    private void ExecutePipeline()
    {
        CommandBuffer cmd = new CommandBuffer();
        cmd.name = "MaterialPipeline";

        int activeStages = 0;
        for (int i = 0; i < materialPipeline.Count; i++)
        {
            if (materialPipeline[i].enabled && materialPipeline[i].material != null)
                activeStages++;
        }

        if (activeStages == 0)
        {
            if (logPipelineSteps)
                Debug.LogWarning("MaterialPipelineManager: No enabled materials in pipeline");
            return;
        }

        currentReadTexture = 0;
        int stageIndex = 0;

        // Execute each material stage
        for (int i = 0; i < materialPipeline.Count; i++)
        {
            if (!materialPipeline[i].enabled || materialPipeline[i].material == null)
                continue;

            Material mat = materialPipeline[i].material;
            RenderTexture source = pingPongTextures[currentReadTexture];
            RenderTexture target = pingPongTextures[1 - currentReadTexture];

            // Blit: source → material → target
            cmd.Blit(source, target, mat);

            if (logPipelineSteps)
                Debug.Log($"  Stage {stageIndex}: {materialPipeline[i].stageName} → {source.name} → {target.name}");

            // Swap for next iteration
            currentReadTexture = 1 - currentReadTexture;
            stageIndex++;
        }

        // Output final result to renderer
        RenderTexture finalOutput = pingPongTextures[currentReadTexture];
        cmd.SetGlobalTexture(outputPropertyName, finalOutput);

        Graphics.ExecuteCommandBuffer(cmd);
        cmd.Dispose();

        // Also set on output renderer for display
        if (outputRenderer != null)
            outputRenderer.material.SetTexture(outputPropertyName, finalOutput);
    }

    /// <summary>
    /// Add a new material stage to the pipeline
    /// </summary>
    public void AddMaterialStage(Material material, string stageName = "Custom Effect")
    {
        if (material == null)
        {
            Debug.LogWarning("MaterialPipelineManager: Cannot add null material");
            return;
        }

        MaterialStage stage = new MaterialStage
        {
            material = material,
            stageName = stageName,
            enabled = true
        };

        materialPipeline.Add(stage);
        if (logPipelineSteps)
            Debug.Log($"MaterialPipelineManager: Added stage '{stageName}'");
    }

    /// <summary>
    /// Remove material stage by index
    /// </summary>
    public void RemoveMaterialStage(int index)
    {
        if (index >= 0 && index < materialPipeline.Count)
        {
            materialPipeline.RemoveAt(index);
            if (logPipelineSteps)
                Debug.Log($"MaterialPipelineManager: Removed stage at index {index}");
        }
    }

    /// <summary>
    /// Toggle a stage on/off
    /// </summary>
    public void SetStageEnabled(int index, bool enabled)
    {
        if (index >= 0 && index < materialPipeline.Count)
        {
            materialPipeline[index].enabled = enabled;
            if (logPipelineSteps)
                Debug.Log($"MaterialPipelineManager: Stage {index} ({materialPipeline[index].stageName}) {(enabled ? "enabled" : "disabled")}");
        }
    }

    /// <summary>
    /// Reorder materials in pipeline
    /// </summary>
    public void MoveMaterialStage(int fromIndex, int toIndex)
    {
        if (fromIndex >= 0 && fromIndex < materialPipeline.Count &&
            toIndex >= 0 && toIndex < materialPipeline.Count && fromIndex != toIndex)
        {
            MaterialStage stage = materialPipeline[fromIndex];
            materialPipeline.RemoveAt(fromIndex);
            materialPipeline.Insert(toIndex, stage);

            if (logPipelineSteps)
                Debug.Log($"MaterialPipelineManager: Moved stage from {fromIndex} to {toIndex}");
        }
    }

    /// <summary>
    /// Clear all stages
    /// </summary>
    public void ClearPipeline()
    {
        materialPipeline.Clear();
        if (logPipelineSteps)
            Debug.Log("MaterialPipelineManager: Pipeline cleared");
    }

    /// <summary>
    /// Get current stage count
    /// </summary>
    public int GetActiveStageCount()
    {
        int count = 0;
        foreach (var stage in materialPipeline)
        {
            if (stage.enabled && stage.material != null)
                count++;
        }
        return count;
    }

    /// <summary>
    /// Resize pipeline textures
    /// </summary>
    public void ResizePipelineTextures(int width, int height)
    {
        pipelineTextureWidth = width;
        pipelineTextureHeight = height;
        CreatePingPongTextures();

        if (logPipelineSteps)
            Debug.Log($"MaterialPipelineManager: Resized textures to {width}x{height}");
    }

    /// <summary>
    /// Get pipeline info for debugging
    /// </summary>
    public string GetPipelineInfo()
    {
        string info = $"MaterialPipelineManager Pipeline Info:\n";
        info += $"  Total Stages: {materialPipeline.Count}\n";
        info += $"  Active Stages: {GetActiveStageCount()}\n";
        info += $"  Texture Size: {pipelineTextureWidth}x{pipelineTextureHeight}\n";
        info += $"  Format: {textureFormat}\n";
        info += $"  Stages:\n";

        for (int i = 0; i < materialPipeline.Count; i++)
        {
            string status = materialPipeline[i].enabled ? "✓" : "✗";
            info += $"    [{i}] {status} {materialPipeline[i].stageName}\n";
        }

        return info;
    }
}
