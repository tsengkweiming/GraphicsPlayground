using UnityEngine;

public class ShaderController : MonoBehaviour
{
    [SerializeField] protected Shader _shader;
    [SerializeField] protected Material _material;
    [SerializeField] protected bool blitToRenderTexture;
    [SerializeField] protected Vector2Int renderTextureSize;
    [SerializeField] private RenderTextureFormat textureFormat = RenderTextureFormat.ARGB32;
    [SerializeField] protected bool _replaceRendererMaterial;
    [SerializeField] protected float _interpolationSpeed = 2f;
    protected RenderTexture _renderTexture;
    public Material Material => _material;
    public RenderTexture RenderTexture => _renderTexture;
    // A stage can consume a camera target, a RenderTexture, or any other
    // Unity texture. Keeping this as Texture makes the input boundary useful
    // for both live camera output and ordinary texture assets.
    public Texture Source { get; set; }
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    protected virtual void Start()
    {
        EnsureMaterial();
        
        if(_replaceRendererMaterial)
            GetComponent<Renderer>().material = _material;

        if (blitToRenderTexture && !_renderTexture)
            CreateRenderTexture();
    }

    protected void EnsureMaterial()
    {
        if (!_material && _shader)
        {
            _material = new Material(_shader);
        }
    }

    protected void CreateRenderTexture()
    {
        ReleaseRT();
        _renderTexture = new RenderTexture(renderTextureSize.x, renderTextureSize.y, 0, textureFormat)
        {
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
    }

    private void ReleaseRT()
    {
        if (_renderTexture)
        {
            _renderTexture.Release();
            Destroy(_renderTexture);
            _renderTexture = null;
        }
    }
    
    protected virtual void OnDestroy()
    {
        if (_material != null)
        {
            if (Application.isPlaying)
            {
                Destroy(_material);
            }
            else
            {
                DestroyImmediate(_material);
            }
        }

        _material = null;
        
        ReleaseRT();
    }
}
