using UnityEngine;

/// <summary>
/// Inspector-based controller for Flower ASCII shader parameters.
/// Adjust all parameters directly in Inspector.
/// </summary>
public class AsciiArtController : ShaderController
{
    [SerializeField] private Renderer targetRenderer;

    [Header("Shader Parameters")]
    [SerializeField] [Range(10, 150)] private float resolution = 59f;
    [SerializeField] [Range(2, 8)] private float posterizeLevels = 5f;
    [SerializeField] private Color backgroundColor = Color.white;
    [SerializeField] private bool flipY = false;

    private Material shaderMaterial;
    private float lastResolution = -1f;
    private float lastPosterizeLevels = -1f;

    private void OnEnable()
    {
        if (targetRenderer == null)
            targetRenderer = GetComponent<Renderer>();

        shaderMaterial = targetRenderer.material;
    }

    private void Update()
    {
        if (shaderMaterial == null) return;

        // Update resolution if changed
        if (!Mathf.Approximately(resolution, lastResolution))
        {
            shaderMaterial.SetFloat("_Resolution", resolution);
            lastResolution = resolution;
        }

        // Update posterize levels if changed
        if (!Mathf.Approximately(posterizeLevels, lastPosterizeLevels))
        {
            shaderMaterial.SetFloat("_PosterizeLevels", posterizeLevels);
            lastPosterizeLevels = posterizeLevels;
        }

        // Update background color
        shaderMaterial.SetColor("_BackgroundColor", backgroundColor);

        // Update flip Y
        shaderMaterial.SetFloat("_FlipY", flipY ? 1f : 0f);
        
        if(blitToRenderTexture)
            Graphics.Blit(Source, _renderTexture, shaderMaterial);
    }
}
