using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(PhysarumSimulation))]
public sealed class PhysarumSimulationEditor : Editor
{
    private SerializedProperty selectedPatternProperty;
    private SerializedProperty spawnShapeProperty;

    private void OnEnable()
    {
        selectedPatternProperty = serializedObject.FindProperty("selectedPattern");
        spawnShapeProperty = serializedObject.FindProperty("spawnShape");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.LabelField("Pattern Controls", EditorStyles.boldLabel);
        DrawEnumSlider<PhysarumSimulation.Pattern>(selectedPatternProperty, "Pattern");
        DrawEnumSlider<PhysarumSimulation.SpawnShape>(spawnShapeProperty, "Spawn Shape");
        EditorGUILayout.Space();

        DrawPropertiesExcluding(
            serializedObject,
            "m_Script",
            "selectedPattern",
            "spawnShape");

        serializedObject.ApplyModifiedProperties();
        EditorGUILayout.Space();

        var simulation = (PhysarumSimulation)target;
        if (GUILayout.Button("Reapply Current Pattern"))
        {
            Undo.RecordObject(simulation, "Apply Physarum Pattern");
            simulation.ApplySelectedPreset();
            EditorUtility.SetDirty(simulation);
        }

        using (new EditorGUI.DisabledScope(!Application.isPlaying))
        {
            if (GUILayout.Button("Reset Simulation"))
                simulation.ResetSimulation();

            if (GUILayout.Button(simulation.IsPaused ? "Resume Simulation" : "Pause Simulation"))
                simulation.TogglePaused();
        }

        EditorGUILayout.HelpBox(
            "Pattern selection applies automatically. Spawn-shape changes reset agents automatically. Resolution or agent-count changes rebuild GPU resources; most other values tune live.",
            MessageType.Info);
    }

    private static void DrawEnumSlider<TEnum>(SerializedProperty property, string label)
        where TEnum : System.Enum
    {
        string[] names = System.Enum.GetNames(typeof(TEnum));
        int maximum = Mathf.Max(0, names.Length - 1);
        int current = Mathf.Clamp(property.enumValueIndex, 0, maximum);

        EditorGUI.BeginChangeCheck();
        int selected = EditorGUILayout.IntSlider(label, current, 0, maximum);
        if (EditorGUI.EndChangeCheck())
            property.enumValueIndex = selected;

        using (new EditorGUI.IndentLevelScope())
            EditorGUILayout.LabelField("Selected", ObjectNames.NicifyVariableName(names[selected]));
    }

    [MenuItem("GameObject/Graphics Playground/Physarum Simulation", false, 10)]
    private static void CreatePhysarumSimulation(MenuCommand menuCommand)
    {
        var gameObject = new GameObject("Physarum Simulation");
        GameObjectUtility.SetParentAndAlign(gameObject, menuCommand.context as GameObject);
        Undo.RegisterCreatedObjectUndo(gameObject, "Create Physarum Simulation");
        Undo.AddComponent<MeshFilter>(gameObject);
        Undo.AddComponent<MeshRenderer>(gameObject);
        PhysarumSimulation simulation = Undo.AddComponent<PhysarumSimulation>(gameObject);
        simulation.ApplySelectedPreset();
        gameObject.transform.localScale = new Vector3(16f, 16f, 1f);
        Selection.activeGameObject = gameObject;
    }
}
