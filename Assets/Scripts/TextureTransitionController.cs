using UnityEngine;

/// <summary>
/// Inspector-based controller for texture blend transitions.
/// Adjust all parameters directly in Inspector.
/// </summary>
public class TextureTransitionController : MonoBehaviour
{
    [SerializeField] private Renderer targetRenderer;
    [SerializeField] private Texture2D[] textureSequence;

    [Header("Transition Settings")]
    [SerializeField] [Range(0, 7)] private int transitionMode = 0;
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

    private Material transitionMaterial;
    private int currentTextureIndex = 0;
    private int nextTextureIndex = 1;
    private float textureChangeTimer = 0f;

    private void OnEnable()
    {
        if (targetRenderer == null)
            targetRenderer = GetComponent<Renderer>();

        transitionMaterial = targetRenderer.material;
        InitializeTextures();
    }

    private void InitializeTextures()
    {
        if (textureSequence == null || textureSequence.Length < 2)
        {
            Debug.LogError("Need at least 2 textures in sequence!");
            return;
        }

        SetTextureTransition(0, 1);
    }

    private void Update()
    {
        if (transitionMaterial == null || textureSequence == null || textureSequence.Length < 2)
            return;

        // Auto-advance texture sequence based on transitionSpeed
        textureChangeTimer += Time.deltaTime;
        float cycleDuration = 1f / transitionSpeed;

        if (textureChangeTimer >= cycleDuration)
        {
            textureChangeTimer = 0f;
            NextTexture();
        }

        // Update transition parameters
        transitionMaterial.SetInt("_BlendMode", transitionMode);
        transitionMaterial.SetFloat("_BlendAmount", blendAmount);
        transitionMaterial.SetFloat("_TransitionSpeed", transitionSpeed);
        transitionMaterial.SetFloat("_UseTime", useTimeAuto ? 1f : 0f);

        // Update noise/pattern parameters
        transitionMaterial.SetFloat("_NoiseScale", noiseScale);
        transitionMaterial.SetFloat("_Distortion", distortion);
        transitionMaterial.SetFloat("_WaveAmplitude", waveAmplitude);
        transitionMaterial.SetFloat("_WaveFrequency", waveFrequency);

        // Update SDF parameters
        transitionMaterial.SetFloat("_SDFScale", sdfScale);
        transitionMaterial.SetFloat("_SDFThickness", sdfThickness);
        transitionMaterial.SetFloat("_SDFSmoothing", sdfSmoothing);
    }

    private void SetTextureTransition(int fromIdx, int toIdx)
    {
        if (textureSequence == null || textureSequence.Length < 2)
            return;

        currentTextureIndex = Mathf.Clamp(fromIdx, 0, textureSequence.Length - 1);
        nextTextureIndex = Mathf.Clamp(toIdx, 0, textureSequence.Length - 1);

        transitionMaterial.SetTexture("_TextureA", textureSequence[currentTextureIndex]);
        transitionMaterial.SetTexture("_TextureB", textureSequence[nextTextureIndex]);

        Debug.Log($"Transition: {currentTextureIndex} → {nextTextureIndex}");
    }

    /// <summary>
    /// Advance to next texture pair in sequence.
    /// Both currentTextureIndex and nextTextureIndex increment and wrap around.
    /// </summary>
    public void NextTexture()
    {
        if (textureSequence == null || textureSequence.Length < 2)
            return;

        currentTextureIndex = (currentTextureIndex + 1) % textureSequence.Length;
        nextTextureIndex = (nextTextureIndex + 1) % textureSequence.Length;

        transitionMaterial.SetTexture("_TextureA", textureSequence[currentTextureIndex]);
        transitionMaterial.SetTexture("_TextureB", textureSequence[nextTextureIndex]);

        Debug.Log($"Next: {currentTextureIndex} → {nextTextureIndex}");
    }

    /// <summary>
    /// Go back to previous texture pair in sequence.
    /// Both currentTextureIndex and nextTextureIndex decrement and wrap around.
    /// </summary>
    public void PreviousTexture()
    {
        if (textureSequence == null || textureSequence.Length < 2)
            return;

        currentTextureIndex = (currentTextureIndex - 1 + textureSequence.Length) % textureSequence.Length;
        nextTextureIndex = (nextTextureIndex - 1 + textureSequence.Length) % textureSequence.Length;

        transitionMaterial.SetTexture("_TextureA", textureSequence[currentTextureIndex]);
        transitionMaterial.SetTexture("_TextureB", textureSequence[nextTextureIndex]);

        Debug.Log($"Prev: {currentTextureIndex} → {nextTextureIndex}");
    }

}
