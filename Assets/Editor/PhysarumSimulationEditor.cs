using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(PhysarumSimulation))]
public sealed class PhysarumSimulationEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        EditorGUILayout.Space();

        var simulation = (PhysarumSimulation)target;
        if (GUILayout.Button("Apply Selected Pattern"))
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
            "Changing resolution or agent count rebuilds GPU resources. Most other values can be tuned live without resetting.",
            MessageType.Info);
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
