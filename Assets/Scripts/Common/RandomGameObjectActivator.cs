using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public enum EaseMode
{
    Linear,
    EaseIn,
    EaseOut,
    EaseInOut
}

/// <summary>
/// Periodically selects a configurable number of unique GameObjects and keeps
/// only those objects active.
/// </summary>
public class RandomGameObjectActivator : MonoBehaviour
{
    [SerializeField] private GameObject[] targetObjects;

    [Min(0.01f)]
    [SerializeField] private float intervalSeconds = 1f;

    [Min(0)]
    [SerializeField] private int randomCount = 1;

    [Min(0f)]
    [SerializeField] private float activationDuration = 0.5f;

    [SerializeField] private EaseMode easeMode = EaseMode.EaseOut;

    private readonly List<GameObject> _validObjects = new List<GameObject>();
    private readonly List<GameObject> _activeObjects = new List<GameObject>();
    private readonly List<GameObject> _nextActiveObjects = new List<GameObject>();
    private readonly HashSet<GameObject> _nextActiveLookup = new HashSet<GameObject>();
    private readonly Dictionary<GameObject, Vector3> _originalScales = new Dictionary<GameObject, Vector3>();
    private readonly Dictionary<GameObject, Coroutine> _scaleCoroutines = new Dictionary<GameObject, Coroutine>();

    private float _nextTriggerTime;
    private bool _hasAppliedSelection;

    private void Start()
    {
        SetRandomObjects();
        ScheduleNextTrigger();
    }

    private void Update()
    {
        if (Time.time < _nextTriggerTime)
            return;

        SetRandomObjects();
        ScheduleNextTrigger();
    }

    /// <summary>
    /// Immediately chooses a new unique selection from targetObjects.
    /// Removed objects are disabled before newly selected objects are enabled.
    /// </summary>
    public void SetRandomObjects()
    {
        BuildValidObjectList();
        BuildNextSelection();

        // On the first run, clear any objects that were already active in the
        // Inspector so the requested randomCount is respected immediately.
        if (!_hasAppliedSelection)
        {
            for (int i = 0; i < _validObjects.Count; i++)
            {
                GameObject targetObject = _validObjects[i];
                if (!_nextActiveLookup.Contains(targetObject))
                    targetObject.SetActive(false);
            }
        }

        // Turn off objects that are no longer selected first.
        for (int i = _activeObjects.Count - 1; i >= 0; i--)
        {
            GameObject activeObject = _activeObjects[i];
            if (activeObject == null || !_nextActiveLookup.Contains(activeObject))
            {
                if (activeObject != null)
                    DisableObject(activeObject);

                _activeObjects.RemoveAt(i);
            }
        }

        // Keep selected objects that are already active untouched, and only
        // enable objects newly added to the selection.
        for (int i = 0; i < _nextActiveObjects.Count; i++)
        {
            GameObject nextObject = _nextActiveObjects[i];
            if (_activeObjects.Contains(nextObject))
                continue;

            ActivateObject(nextObject);
            _activeObjects.Add(nextObject);
        }

        _hasAppliedSelection = true;
    }

    private void BuildValidObjectList()
    {
        _validObjects.Clear();

        if (targetObjects == null)
            return;

        for (int i = 0; i < targetObjects.Length; i++)
        {
            GameObject targetObject = targetObjects[i];
            if (targetObject != null && !_validObjects.Contains(targetObject))
                _validObjects.Add(targetObject);
        }
    }

    private void BuildNextSelection()
    {
        _nextActiveObjects.Clear();
        _nextActiveLookup.Clear();

        int selectionCount = Mathf.Clamp(randomCount, 0, _validObjects.Count);
        for (int i = 0; i < selectionCount; i++)
        {
            int randomIndex = Random.Range(i, _validObjects.Count);
            GameObject swappedObject = _validObjects[i];
            _validObjects[i] = _validObjects[randomIndex];
            _validObjects[randomIndex] = swappedObject;

            GameObject selectedObject = _validObjects[i];
            _nextActiveObjects.Add(selectedObject);
            _nextActiveLookup.Add(selectedObject);
        }
    }

    private void ScheduleNextTrigger()
    {
        _nextTriggerTime = Time.time + Mathf.Max(0.01f, intervalSeconds);
    }

    private void ActivateObject(GameObject targetObject)
    {
        if (!_originalScales.TryGetValue(targetObject, out Vector3 targetScale))
        {
            targetScale = targetObject.transform.localScale;
            _originalScales.Add(targetObject, targetScale);
        }

        StopScaleInterpolation(targetObject);
        targetObject.SetActive(true);

        float duration = Mathf.Max(0f, activationDuration);
        if (duration <= Mathf.Epsilon)
        {
            targetObject.transform.localScale = targetScale;
            return;
        }

        targetObject.transform.localScale = Vector3.zero;
        _scaleCoroutines[targetObject] = StartCoroutine(InterpolateScale(targetObject, targetScale, duration));
    }

    private void DisableObject(GameObject targetObject)
    {
        StopScaleInterpolation(targetObject);
        targetObject.SetActive(false);

        if (_originalScales.TryGetValue(targetObject, out Vector3 originalScale))
            targetObject.transform.localScale = originalScale;
    }

    private void StopScaleInterpolation(GameObject targetObject)
    {
        if (!_scaleCoroutines.TryGetValue(targetObject, out Coroutine coroutine))
            return;

        if (coroutine != null)
            StopCoroutine(coroutine);

        _scaleCoroutines.Remove(targetObject);
    }

    private IEnumerator InterpolateScale(GameObject targetObject, Vector3 targetScale, float duration)
    {
        float elapsed = 0f;
        while (elapsed < duration)
        {
            if (targetObject == null)
                yield break;

            float normalizedTime = Mathf.Clamp01(elapsed / Mathf.Max(duration, 0.0001f));
            float easedTime = EvaluateEase(normalizedTime);
            targetObject.transform.localScale = Vector3.LerpUnclamped(Vector3.zero, targetScale, easedTime);

            elapsed += Time.deltaTime;
            yield return null;
        }

        if (targetObject != null)
            targetObject.transform.localScale = targetScale;

        _scaleCoroutines.Remove(targetObject);
    }

    private float EvaluateEase(float normalizedTime)
    {
        switch (easeMode)
        {
            case EaseMode.EaseIn:
                return normalizedTime * normalizedTime;
            case EaseMode.EaseOut:
                return 1f - (1f - normalizedTime) * (1f - normalizedTime);
            case EaseMode.EaseInOut:
                return normalizedTime < 0.5f
                    ? 2f * normalizedTime * normalizedTime
                    : 1f - Mathf.Pow(-2f * normalizedTime + 2f, 2f) * 0.5f;
            default:
                return normalizedTime;
        }
    }

    private void OnValidate()
    {
        intervalSeconds = Mathf.Max(0.01f, intervalSeconds);
        randomCount = Mathf.Max(0, randomCount);
        activationDuration = Mathf.Max(0f, activationDuration);
    }
}
