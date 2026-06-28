using System.Collections;
using UnityEngine;
using Common;

[ExecuteInEditMode]
public class FPSCounter : SingletonMonoBehaviour<FPSCounter>, IGUIShow
{
    private float _deltaTime = 0.0f;
    private float _fps       = 0.0f;

    public Rect  guiRect     = new Rect(0, 0, 512, 32);
    public Color textColor   = Color.white;

    public int   guiDepth = 100;

    public float Fps => _fps;

    #region Debug
    public int fontSize { get; set; }
    public bool isShowGUI { get; set; }
    public void ShowOrHide() { isShowGUI = !isShowGUI; }
    #endregion

    void Start()
    {
        _fps = 30.0f;
    }

    void Update()
    {
        _deltaTime += (Time.deltaTime - _deltaTime) * 0.1f;
        _fps = 1.0f / _deltaTime;
    }

    void OnGUI()
    {
        if (!isShowGUI) return;
        
        GUI.depth = guiDepth;
        GUIStyle style = new GUIStyle();
        Rect rect = guiRect;
        style.alignment = TextAnchor.UpperLeft;
        style.fontSize = fontSize;
        style.normal.textColor = textColor;
        float msec = _deltaTime * 1000.0f;
        string text = string.Format("{0:0.00} ms ({1:0.00} fps)", msec, _fps);
        GUI.Label(rect, text, style);
    }
}