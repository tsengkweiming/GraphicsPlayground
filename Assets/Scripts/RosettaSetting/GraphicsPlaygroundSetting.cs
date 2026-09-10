using System.Collections.Generic;
using RosettaUI;
using UnityEngine;
using UnityEngine.UIElements;
using PrefsGUI;
using VJ.CameraMovement;

public class GraphicsPlaygroundSetting : MonoBehaviour
{
    private RosettaUIRoot root;
    private WindowElement rootWindow;
    private UIDocument uiDocument;
    
    [SerializeField] private AsciiArtQuadtree3DRenderer quadtreeRenderer;
    [SerializeField] private PhysarumSimulation physarumSimulation;
    [SerializeField] private CameraController cameraController;
    [SerializeField] private RandomTransformer[] randomTransformers;
    [SerializeField] private RandomGameObjectActivator[] randomGameObjectActivators;
    
    private PrefsAny<CameraControllerParam> _cameraControllerParam = new ("CameraControllerParam");
    private PrefsList<RandomTransformerParam> _randomTransformerParamList = new ("RandomTransformerParamList");
    private PrefsList<GameObjectActivatorParam> _gameObjectActivatorParamList = new ("GameObjectActivatorParamList");
    private PrefsList<AsciiQuadtreeParam> _quadtreeParams = new ("AsciiQuadtreeParam");
    private PrefsInt _quadtreeParamIndex = new ("QuadtreeParamIndex");
    private PrefsList<PhysarumSimulationParam> _physarumParams = new ("PhysarumSimulationParam");
    private PrefsInt _physarumParamIndex = new ("PhysarumParamIndex");
    private bool _applyingPhysarumSetting;
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        root = GetComponent<RosettaUIRoot>();
        UnityEngine.Assertions.Assert.IsNotNull(root);

        if (physarumSimulation != null && _physarumParams.Count == 0)
            _physarumParams.Set(new List<PhysarumSimulationParam> { physarumSimulation.Param });

        var rootElement = CreateElement();
        root.Build(rootElement);
        ApplyPhysarumSetting();

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

        var cameraControllerWindow = UI.Window(
            UI.Field(() => _cameraControllerParam).RegisterValueChangeCallback(ApplySetting)
        );

        var settingsWindow = UI.Window(
            // UI.Label("AsciiQuadtreeSetting"),
            UI.Field(() => _quadtreeParams).RegisterValueChangeCallback(ApplySetting),
            UI.Field(() => _quadtreeParamIndex).RegisterValueChangeCallback(ApplySetting)
        );

        var physarumSettingsWindow = UI.Window(
            UI.Field(() => _physarumParams).RegisterValueChangeCallback(ApplyPhysarumSetting),
            UI.Field(() => _physarumParamIndex).RegisterValueChangeCallback(ApplyPhysarumSetting)
        );

        rootWindow = UI.Window(
            UI.Label(menu[0] + menu[1]),
            UI.WindowLauncher(UI.Label("CameraController"), cameraControllerWindow),
            UI.WindowLauncher(UI.Label("AsciiQuadtree"), settingsWindow),
            UI.WindowLauncher(UI.Label("PhysarumSimulation"), physarumSettingsWindow),
            UI.Button("Save", Prefs.Save)
        ).SetClosable(false);
        return rootWindow;
    }


    private void ApplySetting()
    {
        if (cameraController != null)
            cameraController.Param = _cameraControllerParam.Get();
        
        if (quadtreeRenderer != null && _quadtreeParams.Count > 0)
            quadtreeRenderer.Param = _quadtreeParams[Mathf.Clamp(_quadtreeParamIndex, 0, _quadtreeParams.Count - 1)];
    }

    private void ApplyPhysarumSetting()
    {
        if (_applyingPhysarumSetting || physarumSimulation == null || _physarumParams.Count == 0)
            return;

        _applyingPhysarumSetting = true;
        try
        {
            int index = Mathf.Clamp(_physarumParamIndex, 0, _physarumParams.Count - 1);
            physarumSimulation.Param = _physarumParams[index];

            // A pattern selection can change the simulation's spawn shape.
            // Store that resolved value back so the UI reflects the active preset.
            _physarumParams[index] = physarumSimulation.Param;
        }
        finally
        {
            _applyingPhysarumSetting = false;
        }
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
