using UnityEngine;
using UnityEngine.Playables;

public class LightGIValueBehaviour : PlayableBehaviour
{
    public TextGIParam textGIParam;

    public override void ProcessFrame(Playable playable, FrameData info, object playerData)
    {
        // playerData holds the track binding target object
        ProceduralTextGIController targetComponent = playerData as ProceduralTextGIController;

        if (targetComponent != null)
        {
            // Set the runtime values onto the class instance
            targetComponent.TextGIParam = textGIParam;
        }
    }
}
