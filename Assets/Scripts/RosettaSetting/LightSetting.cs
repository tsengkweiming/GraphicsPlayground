using RosettaSetting;
using RosettaUI;
using UnityEngine;
using UnityEngine.UIElements;

public class LightSetting : MonoBehaviour
{
    private RosettaUIRoot root;
    private WindowElement rootWindow;
    private UIDocument uiDocument;
    
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

        rootWindow = UI.Window(
                UI.Label(menu[0] + menu[1]),
                UI.WindowLauncher<TextGIControllerSetting>("TextGIControllerSetting")
            ).SetClosable(false);;
        return rootWindow;
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
