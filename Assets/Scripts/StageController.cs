using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class StageData
{
    public string stageName;
    public int oscId;
    public GameObject[] targetObjects;
    public RandomObject[] randomObjectSet;
}

[Serializable]
public class RandomObject
{
    public GameObject[] randomObjects;
    public bool applyEase;
}
public class StageController : SingletonMonoBehaviour<StageController>
{
    [SerializeField] private StageData[] stageDatas = Array.Empty<StageData>();
    [SerializeField] private GameObject testStage;

    [Header("Target Scale Animation")]
    [Min(0f)]
    [SerializeField] private float targetScaleDuration = 0.5f;
    [SerializeField] private EaseMode targetScaleEase = EaseMode.EaseOut;

    private StageData _activeStageData;
    private readonly Dictionary<RandomObject, GameObject> _activeRandomObjects =
        new ();
    private readonly Dictionary<RandomObject, GameObject> _nextRandomSelections =
        new ();
    private readonly HashSet<GameObject> _nextRandomObjects = new ();
    private readonly HashSet<GameObject> _currentlyActiveRandomObjects = new ();
    private readonly Dictionary<GameObject, Vector3> _originalTargetScales =
        new ();
    private readonly Dictionary<GameObject, Coroutine> _targetScaleCoroutines =
        new ();

    public int CurrentOscId { get; private set; } = -1;

    /// <summary>
    /// Activates the stage whose oscId matches the supplied value.
    /// Previous target objects are disabled before a new stage is activated.
    /// </summary>
    public void SetStage(int oscId)
    {
        StageData nextStageData = FindStage(oscId);
        if (nextStageData == null)
        {
            DisableAllManagedObjects();
            _activeStageData = null;
            CurrentOscId = -1;
            Debug.LogWarning($"StageController: No stage found for oscId {oscId}.");
            return;
        }

        bool isNewStage = _activeStageData != nextStageData;
        if (isNewStage)
            DisableAllManagedTargetObjects();

        SetObjectsActive(nextStageData.targetObjects, true);

        SetRandomObjects(nextStageData.randomObjectSet);

        _activeStageData = nextStageData;
        CurrentOscId = oscId;
    }

    public void SetTestStage(bool state)
    {
        testStage.SetActive(state);
    }

    /// <summary>
    /// Disables every object referenced by every configured stage.
    /// </summary>
    public void DisableAllStages()
    {
        DisableAllManagedObjects();
        _activeStageData = null;
        CurrentOscId = -1;
    }

    private StageData FindStage(int oscId)
    {
        if (stageDatas == null)
            return null;

        foreach (var stageData in stageDatas)
        {
            if (stageData != null && stageData.oscId == oscId)
                return stageData;
        }

        return null;
    }

    private static GameObject ChooseRandomObject(GameObject[] randomObjects)
    {
        if (randomObjects == null || randomObjects.Length == 0)
            return null;

        int validObjectCount = 0;
        foreach (var randomObject in randomObjects)
        {
            if (randomObject != null)
                validObjectCount++;
        }

        if (validObjectCount == 0)
            return null;

        int selectedObject = UnityEngine.Random.Range(0, validObjectCount);
        foreach (var randomObject in randomObjects)
        {
            if (randomObject == null)
                continue;

            if (selectedObject == 0)
                return randomObject;

            selectedObject--;
        }

        return null;
    }

    private void DisableAllManagedObjects()
    {
        DisableAllManagedTargetObjects();
        SetRandomObjects(null);
    }

    private void DisableAllManagedTargetObjects()
    {
        if (stageDatas == null)
            return;

        for (int i = 0; i < stageDatas.Length; i++)
        {
            StageData stageData = stageDatas[i];
            if (stageData == null)
                continue;

            SetObjectsActive(stageData.targetObjects, false);
        }
    }

    private void SetRandomObjects(RandomObject[] randomObjectSets)
    {
        _nextRandomSelections.Clear();
        _nextRandomObjects.Clear();
        _currentlyActiveRandomObjects.Clear();

        if (randomObjectSets != null)
        {
            for (int i = 0; i < randomObjectSets.Length; i++)
            {
                RandomObject randomObjectSet = randomObjectSets[i];
                if (randomObjectSet == null)
                    continue;

                GameObject selectedObject = ChooseRandomObject(randomObjectSet.randomObjects);
                _nextRandomSelections[randomObjectSet] = selectedObject;

                if (selectedObject != null)
                    _nextRandomObjects.Add(selectedObject);
            }
        }

        foreach (GameObject activeObject in _activeRandomObjects.Values)
        {
            if (activeObject != null)
                _currentlyActiveRandomObjects.Add(activeObject);
        }

        // Turn off former random objects first. Objects still selected by
        // another random set remain active.
        foreach (GameObject activeObject in _currentlyActiveRandomObjects)
        {
            if (!_nextRandomObjects.Contains(activeObject))
                activeObject.SetActive(false);
        }

        // Activate every selected object that was not already active.
        foreach (GameObject nextObject in _nextRandomObjects)
        {
            if (!_currentlyActiveRandomObjects.Contains(nextObject))
                nextObject.SetActive(true);
        }

        _activeRandomObjects.Clear();
        foreach (KeyValuePair<RandomObject, GameObject> selection in _nextRandomSelections)
            _activeRandomObjects[selection.Key] = selection.Value;
    }

    private void SetObjectsActive(GameObject[] objects, bool isActive)
    {
        if (objects == null)
            return;

        for (int i = 0; i < objects.Length; i++)
        {
            GameObject targetObject = objects[i];
            if (targetObject == null)
                continue;

            if (isActive)
                ActivateTargetObject(targetObject);
            else
                DisableTargetObject(targetObject);
        }
    }

    private void ActivateTargetObject(GameObject targetObject)
    {
        CacheOriginalScale(targetObject);

        // Do not restart an in-progress interpolation when the same stage is triggered again.
        if (targetObject.activeSelf)
            return;

        StopTargetScaleInterpolation(targetObject);
        targetObject.SetActive(true);

        float duration = Mathf.Max(0f, targetScaleDuration);
        if (duration <= Mathf.Epsilon)
        {
            targetObject.transform.localScale = _originalTargetScales[targetObject];
            return;
        }

        targetObject.transform.localScale = Vector3.zero;
        _targetScaleCoroutines[targetObject] = StartCoroutine(InterpolateTargetScale(
            targetObject,
            _originalTargetScales[targetObject],
            duration));
    }

    private void DisableTargetObject(GameObject targetObject)
    {
        CacheOriginalScale(targetObject);
        StopTargetScaleInterpolation(targetObject);
        targetObject.SetActive(false);
        targetObject.transform.localScale = _originalTargetScales[targetObject];
    }

    private void CacheOriginalScale(GameObject targetObject)
    {
        if (!_originalTargetScales.ContainsKey(targetObject))
            _originalTargetScales.Add(targetObject, targetObject.transform.localScale);
    }

    private void StopTargetScaleInterpolation(GameObject targetObject)
    {
        if (!_targetScaleCoroutines.TryGetValue(targetObject, out Coroutine coroutine))
            return;

        if (coroutine != null)
            StopCoroutine(coroutine);

        _targetScaleCoroutines.Remove(targetObject);
    }

    private IEnumerator InterpolateTargetScale(
        GameObject targetObject,
        Vector3 targetScale,
        float duration)
    {
        float elapsed = 0f;
        while (elapsed < duration)
        {
            if (targetObject == null)
                yield break;

            float normalizedTime = Mathf.Clamp01(elapsed / Mathf.Max(duration, 0.0001f));
            targetObject.transform.localScale = Vector3.LerpUnclamped(
                Vector3.zero,
                targetScale,
                EvaluateTargetScaleEase(normalizedTime));

            elapsed += Time.deltaTime;
            yield return null;
        }

        if (targetObject != null)
            targetObject.transform.localScale = targetScale;

        _targetScaleCoroutines.Remove(targetObject);
    }

    private float EvaluateTargetScaleEase(float normalizedTime)
    {
        switch (targetScaleEase)
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
}
