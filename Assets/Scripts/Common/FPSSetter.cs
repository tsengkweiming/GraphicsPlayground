using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FPSSetter : MonoBehaviour
{
    [SerializeField]
    int _targetFPS;

    void Awake()
    {
        QualitySettings.vSyncCount  = 0;
        Application.targetFrameRate = _targetFPS;
    }
}
