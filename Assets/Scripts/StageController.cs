using System;
using UnityEngine;

[Serializable]
public class StageData
{
    public string stageName;
    public int oscId;
    public GameObject[] targetObjects;
    public GameObject[] randomObjects;
}
public class StageController : SingletonMonoBehaviour<StageController>
{
    [SerializeField] private StageData[] stageDatas = Array.Empty<StageData>();

    private StageData _activeStageData;
    private GameObject _activeRandomObject;

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

        // Pick first, then switch. If the same object is picked again, it is left untouched.
        SetRandomObject(ChooseRandomObject(nextStageData.randomObjects));
        SetObjectsActive(nextStageData.targetObjects, true);

        _activeStageData = nextStageData;
        CurrentOscId = oscId;
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
        SetRandomObject(null);
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

    private void SetRandomObject(GameObject nextRandomObject)
    {
        if (_activeRandomObject == nextRandomObject)
            return;

        if (_activeRandomObject != null)
            _activeRandomObject.SetActive(false);

        _activeRandomObject = nextRandomObject;
        if (_activeRandomObject != null)
            _activeRandomObject.SetActive(true);
    }

    private static void SetObjectsActive(GameObject[] objects, bool isActive)
    {
        if (objects == null)
            return;

        for (int i = 0; i < objects.Length; i++)
        {
            if (objects[i] != null)
                objects[i].SetActive(isActive);
        }
    }
}
