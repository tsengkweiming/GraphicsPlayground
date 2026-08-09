using UnityEngine;

/// <summary>
/// RenderTexture-based controller for texture blend transitions.
/// Blits transition shader to RenderTexture, outputs result to targetRenderer.
/// Allows post-processing and off-screen rendering.
/// </summary>
public class TextureTransitionController : ShaderController
{
    [SerializeField] private Renderer targetRenderer;
    [SerializeField] private Texture2D[] textureSequence;

    [Header("Transition Settings")]
    [SerializeField] [Range(0, 9)] private int transitionMode = 0;
    [SerializeField] [Range(0, 1)] private float blendAmount = 0.5f;
    [SerializeField] [Range(0.1f, 5f)] private float transitionSpeed = 1.0f;
    [SerializeField] private bool useTimeAuto = false;

    [Header("Pattern Parameters")]
    [SerializeField] [Range(0.1f, 10f)] private float noiseScale = 2.0f;
    [SerializeField] [Range(0, 1)] private float distortion = 0.2f;
    [SerializeField] [Range(0, 1)] private float waveAmplitude = 0.1f;
    [SerializeField] [Range(0.5f, 10f)] private float waveFrequency = 2.0f;

    [Header("SDF Parameters (Advanced mode)")]
    [SerializeField] [Range(1, 20)] private float sdfScale = 4.0f;
    [SerializeField] [Range(0.01f, 0.2f)] private float sdfThickness = 0.05f;
    [SerializeField] [Range(0.001f, 0.1f)] private float sdfSmoothing = 0.02f;

    private int currentTextureIndex = 0;
    private int nextTextureIndex = 1;
    private float transitionProgress = 0f;

    private void OnEnable()
    {
        if (targetRenderer == null)
            targetRenderer = GetComponent<Renderer>();

        InitializeTextures();
    }

    protected override void Start()
    {
        base.Start();

        // ShaderController creates the material in Start, so initialize the
        // texture pair after the material is available.
        InitializeTextures();
    }

    private void InitializeTextures()
    {
        if (textureSequence == null || textureSequence.Length < 2)
        {
            Debug.LogError("TextureTransitionController: Need at least 2 textures in sequence!");
            return;
        }

        transitionProgress = 0f;
        SetTextureTransition(0, 1);
    }

    private void Update()
    {
        if (!_material || textureSequence == null || textureSequence.Length < 2)
            return;

        // The controller is the single owner of transition progress and
        // texture sequencing. The shader only blends the current pair.
        if (useTimeAuto)
        {
            transitionProgress += Time.deltaTime * transitionSpeed;

            if (transitionProgress >= 1f)
            {
                transitionProgress = 0f;
                AdvanceTexturePair();
            }
        }
        else
        {
            transitionProgress = 0f;
        }

        // Update transition parameters
        _material.SetInt("_BlendMode", transitionMode);
        _material.SetFloat("_BlendAmount", useTimeAuto ? transitionProgress : blendAmount);

        // Update noise/pattern parameters
        _material.SetFloat("_NoiseScale", noiseScale);
        _material.SetFloat("_Distortion", distortion);
        _material.SetFloat("_WaveAmplitude", waveAmplitude);
        _material.SetFloat("_WaveFrequency", waveFrequency);

        // Update SDF parameters
        _material.SetFloat("_SDFScale", sdfScale);
        _material.SetFloat("_SDFThickness", sdfThickness);
        _material.SetFloat("_SDFSmoothing", sdfSmoothing);

        // Blit to RenderTexture
        if(blitToRenderTexture)
            Graphics.Blit(Source, _renderTexture, _material);
    }

    private void SetTextureTransition(int fromIdx, int toIdx)
    {
        if (textureSequence == null || textureSequence.Length < 2 || _material == null)
            return;

        currentTextureIndex = Mathf.Clamp(fromIdx, 0, textureSequence.Length - 1);
        nextTextureIndex = Mathf.Clamp(toIdx, 0, textureSequence.Length - 1);

        _material.SetTexture("_TextureA", textureSequence[currentTextureIndex]);
        _material.SetTexture("_TextureB", textureSequence[nextTextureIndex]);

        Debug.Log($"TextureTransitionController: Transition {currentTextureIndex} → {nextTextureIndex}");
    }

    public void NextTexture()
    {
        if (textureSequence == null || textureSequence.Length < 2)
            return;

        transitionProgress = 0f;
        AdvanceTexturePair();
    }

    public void PreviousTexture()
    {
        if (textureSequence == null || textureSequence.Length < 2)
            return;

        currentTextureIndex = (currentTextureIndex - 1 + textureSequence.Length) % textureSequence.Length;
        nextTextureIndex = (currentTextureIndex + 1) % textureSequence.Length;
        transitionProgress = 0f;

        SetTextureTransition(currentTextureIndex, nextTextureIndex);
    }

    private void AdvanceTexturePair()
    {
        currentTextureIndex = nextTextureIndex;
        nextTextureIndex = (nextTextureIndex + 1) % textureSequence.Length;
        SetTextureTransition(currentTextureIndex, nextTextureIndex);
    }

    public void ResizeRenderTexture(int width, int height)
    {
        renderTextureSize.x = width;
        renderTextureSize.y = height;
        CreateRenderTexture();
    }
}
