using System;
using UnityEngine;
using System.Collections;
using Random = UnityEngine.Random;

[Serializable]
public class CameraShakerParam
{
    public float Duration  = 0.25f;  // 抖動時間
    public float Magnitude = 0.15f;  // 抖動幅度（位置）
    public float Angle     = 1.0f;   // 抖動幅度（角度）
    public int ShakeCount = 5;  // 每次觸發要抖幾下
}
public class CameraShaker : MonoBehaviour
{
    [Header("基本設定")] [SerializeField] private CameraShakerParam _param;

    private Vector3    _basePos;   // 每次觸發當下的位置
    private Quaternion _baseRot;   // 每次觸發當下的旋轉
    private Coroutine  _currentCR; // 正在執行的協程

    public CameraShakerParam Param { get => _param; set => _param = value; }

    void Update ()
    {
        // 範例：按 Space 觸發
        if (Input.GetKeyDown(KeyCode.F1))
            Shake();
    }

    /// <summary>外部可呼叫的抖動函式。</summary>
    public void Shake()
    {
        // 若仍在抖，先停止並還原
        if (_currentCR != null)
        {
            StopCoroutine(_currentCR);
            RestoreTransform();
        }

        // 以「當下姿態」作為新的基準
        _basePos = transform.localPosition;
        _baseRot = transform.localRotation;

        _currentCR = StartCoroutine(DoShake());
    }

    private IEnumerator DoShake()
    {
        float elapsed = 0f;
        float interval = _param.Duration / Mathf.Max(1, _param.ShakeCount); // 分段長度
        float nextChange = 0f;

        Vector3 posOffset = Vector3.zero;
        Vector3 rotOffset = Vector3.zero;

        while (elapsed < _param.Duration)
        {
            // 到了下一段就重新抽亂數
            if (elapsed >= nextChange)
            {
                posOffset = Random.insideUnitSphere * _param.Magnitude;
                rotOffset = new Vector3(
                    Random.Range(-_param.Angle, _param.Angle),
                    Random.Range(-_param.Angle, _param.Angle),
                    Random.Range(-_param.Angle, _param.Angle));
                nextChange += interval;
            }

            transform.localPosition = _basePos + posOffset;
            transform.localRotation = _baseRot * Quaternion.Euler(rotOffset);

            elapsed += Time.deltaTime;
            yield return null;
        }

        RestoreTransform();
        _currentCR = null;
    }

    private void RestoreTransform()
    {
        transform.localPosition = _basePos;
        transform.localRotation = _baseRot;
    }
}