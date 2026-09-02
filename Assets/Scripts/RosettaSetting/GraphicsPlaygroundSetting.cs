using System.Collections.Generic;
using RosettaUI;
using UnityEngine;
using UnityEngine.UIElements;
using PrefsGUI;
using PrefsGUI.RosettaUI;

public class GraphicsPlaygroundSetting : MonoBehaviour
{
    private RosettaUIRoot root;
    private WindowElement rootWindow;
    private UIDocument uiDocument;
    
    [SerializeField] private AsciiArtQuadtree3DRenderer quadtreeRenderer;
    
    private PrefsList<AsciiQuadtreeParam> _quadtreeParams = new ("AsciiQuadtreeParam");
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        root = GetComponent<RosettaUIRoot>();
        UnityEngine.Assertions.Assert.IsNotNull(root);

        var rootElement = CreateElement();
        root.Build(rootElement);
        rootWindow.Enable = false;
        SetRootVisible(false);
    }

    Element CreateElement()
    {
        var menu = new string[]
        {
            "Menu : <color=red>" + GetType().Name + "-</color>",
            " (Press <color=red>D</color> to toggle)"
        };

        var settingsWindow = UI.Window(
            // UI.Label("AsciiQuadtreeSetting"),
            UI.Field(() => _quadtreeParams).RegisterValueChangeCallback(ApplySetting)
        );

        rootWindow = UI.Window(
            UI.Label(menu[0] + menu[1]),
            UI.WindowLauncher(UI.Label("AsciiQuadtreeSetting"), settingsWindow),
            UI.Button("Save", Prefs.Save)
        ).SetClosable(false);
        return rootWindow;
    }


    private void ApplySetting()
    {
        quadtreeRenderer.Param = _quadtreeParams[0];
    }
    
    public void Toggle()
    {
        if (rootWindow != null)
        {
            var visible = !rootWindow.Enable;
            rootWindow.Enable = visible;
            SetRootVisible(visible);
        }
    }

    private void SetRootVisible(bool visible)
    {
        uiDocument ??= GetComponent<UIDocument>();
        if (uiDocument?.rootVisualElement != null)
        {
            uiDocument.rootVisualElement.visible = visible;
        }
    }
}
