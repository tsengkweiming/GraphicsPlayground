using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
[CustomEditor(typeof(RandomTransformer))]
public class RandomTransformerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        RandomTransformer transformer = (RandomTransformer)target;

        GUILayout.Space(10);
        GUILayout.Label("Quick Actions", EditorStyles.boldLabel);

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("Lerp to Random Scale", GUILayout.Height(30)))
        {
            transformer.LerpToRandomScale();
        }
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("Lerp to Random Rotation", GUILayout.Height(30)))
        {
            transformer.LerpToRandomRotation();
        }
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("Reset Transform", GUILayout.Height(30)))
        {
            transformer.ResetTransform();
        }
        EditorGUILayout.EndHorizontal();
    }
}
#endif

public class RandomTransformer : MonoBehaviour
{
    [Header("Rotation")]
    public bool enableRotation = true;
    public float rotationSpeed = 90f; // degrees per second
    public Vector3 rotateAxis = Vector3.up;
    public float rotationIntervalMin = 1f;
    public float rotationIntervalMax = 3f;

    [Header("Scaling")]
    public bool enableScaling = true;
    public float scaleSpeed = 0.5f; // units per second
    public bool uniformScale = true;
    public Vector3 minScale = Vector3.one * 0.5f;
    public Vector3 maxScale = Vector3.one * 2f;
    public float scaleIntervalMin = 1f;
    public float scaleIntervalMax = 3f;

    [Header("Lerp Settings")]
    public float lerpDuration = 1f;

    private float rotationNextChangeTime;
    private float rotationCurrentDirection;
    private float scaleNextChangeTime;
    private float scaleCurrentDirection;
    private Vector3 targetScale;
    private Vector3 startScale;
    private float scaleLerpTime;
    private bool isScaleLerping;
    private Quaternion targetRotation;
    private Quaternion startRotation;
    private float rotationLerpTime;
    private bool isRotationLerping;

    void Start()
    {
        if (enableRotation)
            ScheduleNextRotation();
        if (enableScaling)
            ScheduleNextScale();
    }

    void Update()
    {
        if (isRotationLerping)
            UpdateRotationLerp();
        else if (enableRotation)
            UpdateRotation();

        if (isScaleLerping)
            UpdateScaleLerp();
        else if (enableScaling)
            UpdateScale();
    }

    void UpdateRotation()
    {
        var rotate = rotateAxis * (rotationCurrentDirection * rotationSpeed * Time.deltaTime);
        transform.Rotate(rotate.x, rotate.y, rotate.z);

        if (Time.time >= rotationNextChangeTime)
        {
            ScheduleNextRotation();
        }
    }

    void UpdateScale()
    {
        Vector3 scaleChange = Vector3.one * (scaleCurrentDirection * scaleSpeed * Time.deltaTime);

        if (uniformScale)
        {
            transform.localScale += scaleChange;
            float scale = transform.localScale.x;
            float minVal = minScale.x;
            float maxVal = maxScale.x;
            scale = Mathf.Clamp(scale, minVal, maxVal);
            transform.localScale = Vector3.one * scale;
        }
        else
        {
            transform.localScale += scaleChange;
            transform.localScale = Vector3.Min(transform.localScale, maxScale);
            transform.localScale = Vector3.Max(transform.localScale, minScale);
        }

        if (Time.time >= scaleNextChangeTime)
        {
            ScheduleNextScale();
        }
    }

    void UpdateRotationLerp()
    {
        rotationLerpTime += Time.deltaTime;
        float t = Mathf.Clamp01(rotationLerpTime / lerpDuration);
        transform.rotation = Quaternion.Lerp(startRotation, targetRotation, t);

        if (t >= 1f)
        {
            isRotationLerping = false;
        }
    }

    void UpdateScaleLerp()
    {
        scaleLerpTime += Time.deltaTime;
        float t = Mathf.Clamp01(scaleLerpTime / lerpDuration);
        transform.localScale = Vector3.Lerp(startScale, targetScale, t);

        if (t >= 1f)
        {
            isScaleLerping = false;
        }
    }

    void ScheduleNextRotation()
    {
        rotationCurrentDirection = Random.value < 0.5f ? -1f : 1f;
        rotationNextChangeTime = Time.time + Random.Range(rotationIntervalMin, rotationIntervalMax);
    }

    void ScheduleNextScale()
    {
        scaleCurrentDirection = Random.value < 0.5f ? -1f : 1f;
        scaleNextChangeTime = Time.time + Random.Range(scaleIntervalMin, scaleIntervalMax);
    }

    public void LerpToRandomScale()
    {
        startScale = transform.localScale;
        targetScale = new Vector3(
            Random.Range(minScale.x, maxScale.x),
            Random.Range(minScale.y, maxScale.y),
            Random.Range(minScale.z, maxScale.z)
        );
        scaleLerpTime = 0f;
        isScaleLerping = true;
    }

    public void LerpToRandomRotation()
    {
        startRotation = transform.rotation;
        targetRotation = Random.rotation;
        rotationLerpTime = 0f;
        isRotationLerping = true;
    }

    public void ResetTransform()
    {
        transform.rotation = Quaternion.identity;
        transform.localScale = Vector3.one;
        isRotationLerping = false;
        isScaleLerping = false;
    }
}
