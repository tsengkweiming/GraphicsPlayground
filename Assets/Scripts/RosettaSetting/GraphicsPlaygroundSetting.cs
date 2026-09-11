using System.Collections.Generic;
using RosettaUI;
using UnityEngine;
using UnityEngine.UIElements;
using PrefsGUI;
using PrefsGUI.RosettaUI;
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

        SynchronizeRandomTransformerParamList();
        SynchronizeGameObjectActivatorParamList();

        var rootElement = CreateElement();
        root.Build(rootElement);
        ApplyRandomTransformerSettings();
        ApplyGameObjectActivatorSettings();
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

        var randomTransformerSettingsWindow = UI.Window(
            CreateRandomTransformerParamListElement().RegisterValueChangeCallback(ApplySetting)
        );

        var gameObjectActivatorSettingsWindow = UI.Window(
            CreateGameObjectActivatorParamListElement().RegisterValueChangeCallback(ApplySetting)
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
            UI.WindowLauncher(UI.Label("RandomTransformers"), randomTransformerSettingsWindow),
            UI.WindowLauncher(UI.Label("RandomGameObjectActivators"), gameObjectActivatorSettingsWindow),
            UI.WindowLauncher(UI.Label("AsciiQuadtree"), settingsWindow),
            UI.WindowLauncher(UI.Label("PhysarumSimulation"), physarumSettingsWindow),
            UI.Button("Save", Prefs.Save)
        ).SetClosable(false);
        return rootWindow;
    }

    private Element CreateRandomTransformerParamListElement()
    {
        var option = new ListViewOption(reorderable: false, fixedSize: true);
        option.createItemElementFunc = CreateRandomTransformerListItemElement;
        return _randomTransformerParamList.CreateElement(
            UI.Label("RandomTransformerParamList"),
            option
        );
    }

    private Element CreateRandomTransformerListItemElement(IBinder binder, int index)
    {
        return UI.Column(
            UI.ListItemDefault(binder, index),
            UI.Row(
                UI.Button("LerpToRandomScale", () => LerpToRandomScale(index)),
                UI.Button("LerpToRandomRotation", () => LerpToRandomRotation(index)),
                UI.Button("ResetTransform", () => ResetTransform(index))
            )
        );
    }

    private Element CreateGameObjectActivatorParamListElement()
    {
        var option = new ListViewOption(reorderable: false, fixedSize: true);
        option.createItemElementFunc = CreateGameObjectActivatorListItemElement;
        return _gameObjectActivatorParamList.CreateElement(
            UI.Label("GameObjectActivatorParamList"),
            option
        );
    }

    private Element CreateGameObjectActivatorListItemElement(IBinder binder, int index)
    {
        ButtonElement keepButton = null;
        keepButton = UI.Button(
            UI.Label(() => GetKeepButtonLabel(index)),
            () =>
            {
                ToggleKeepGameObjectSelection(index);
                keepButton.NotifyViewValueChanged();
            }
        );

        return UI.Column(
            UI.ListItemDefault(binder, index),
            UI.Row(
                keepButton,
                UI.Button("Next", () => SelectNextGameObjectSelection(index)),
                UI.Button("Previous", () => SelectPreviousGameObjectSelection(index))
            )
        );
    }

    private string GetKeepButtonLabel(int index)
    {
        return TryGetGameObjectActivator(index, out var activator) && activator.IsKeepingSelection
            ? "Resume"
            : "Keep";
    }

    private void LerpToRandomScale(int index)
    {
        ApplyRandomTransformerSettings();
        if (TryGetRandomTransformer(index, out var transformer))
            transformer.LerpToRandomScale();
    }

    private void LerpToRandomRotation(int index)
    {
        ApplyRandomTransformerSettings();
        if (TryGetRandomTransformer(index, out var transformer))
            transformer.LerpToRandomRotation();
    }

    private void ResetTransform(int index)
    {
        if (TryGetRandomTransformer(index, out var transformer))
            transformer.ResetTransform();
    }

    private void ToggleKeepGameObjectSelection(int index)
    {
        SynchronizeGameObjectActivatorParamList();
        if (!TryGetGameObjectActivator(index, out var activator))
            return;

        ApplyGameObjectActivatorSettings();
        activator.KeepCurrentSelection();
    }

    private void SelectNextGameObjectSelection(int index)
    {
        ApplyGameObjectActivatorSettings();
        if (TryGetGameObjectActivator(index, out var activator))
            activator.SelectNextRandomObjects();
    }

    private void SelectPreviousGameObjectSelection(int index)
    {
        ApplyGameObjectActivatorSettings();
        if (TryGetGameObjectActivator(index, out var activator))
            activator.SelectPreviousRandomObjects();
    }

    private bool TryGetRandomTransformer(int index, out RandomTransformer transformer)
    {
        transformer = null;
        if (randomTransformers == null || index < 0 || index >= randomTransformers.Length)
            return false;

        transformer = randomTransformers[index];
        return transformer != null;
    }

    private bool TryGetGameObjectActivator(int index, out RandomGameObjectActivator activator)
    {
        activator = null;
        if (randomGameObjectActivators == null || index < 0 || index >= randomGameObjectActivators.Length)
            return false;

        activator = randomGameObjectActivators[index];
        return activator != null;
    }


    private void ApplySetting()
    {
        if (cameraController != null)
            cameraController.Param = _cameraControllerParam.Get();

        ApplyRandomTransformerSettings();
        ApplyGameObjectActivatorSettings();
        
        if (quadtreeRenderer != null && _quadtreeParams.Count > 0)
            quadtreeRenderer.Param = _quadtreeParams[Mathf.Clamp(_quadtreeParamIndex, 0, _quadtreeParams.Count - 1)];
    }

    private void ApplyRandomTransformerSettings()
    {
        SynchronizeRandomTransformerParamList();

        if (randomTransformers == null)
            return;

        for (int i = 0; i < randomTransformers.Length; i++)
        {
            if (randomTransformers[i] != null)
                randomTransformers[i].Param = _randomTransformerParamList[i];
        }
    }

    private void ApplyGameObjectActivatorSettings()
    {
        SynchronizeGameObjectActivatorParamList();

        if (randomGameObjectActivators == null)
            return;

        for (int i = 0; i < randomGameObjectActivators.Length; i++)
        {
            if (randomGameObjectActivators[i] != null)
                randomGameObjectActivators[i].Param = _gameObjectActivatorParamList[i];
        }
    }

    private void SynchronizeRandomTransformerParamList()
    {
        int targetCount = randomTransformers?.Length ?? 0;
        if (_randomTransformerParamList.Count == targetCount)
            return;

        var parameters = _randomTransformerParamList.Get() ?? new List<RandomTransformerParam>();
        if (parameters.Count > targetCount)
            parameters.RemoveRange(targetCount, parameters.Count - targetCount);

        while (parameters.Count < targetCount)
        {
            int index = parameters.Count;
            RandomTransformerParam parameter = randomTransformers[index]?.Param;
            parameters.Add(parameter ?? new RandomTransformerParam());
        }

        _randomTransformerParamList.Set(parameters);
    }

    private void SynchronizeGameObjectActivatorParamList()
    {
        int targetCount = randomGameObjectActivators?.Length ?? 0;
        if (_gameObjectActivatorParamList.Count == targetCount)
            return;

        var parameters = _gameObjectActivatorParamList.Get() ?? new List<GameObjectActivatorParam>();
        if (parameters.Count > targetCount)
            parameters.RemoveRange(targetCount, parameters.Count - targetCount);

        while (parameters.Count < targetCount)
        {
            int index = parameters.Count;
            GameObjectActivatorParam parameter = randomGameObjectActivators[index]?.Param;
            parameters.Add(parameter ?? new GameObjectActivatorParam());
        }

        _gameObjectActivatorParamList.Set(parameters);
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
