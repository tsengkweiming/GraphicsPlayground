using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

namespace Timeline
{
    public class LightGIValueAsset: PlayableAsset, ITimelineClipAsset
    {
        public TextGIParam textGIParam;

        // Defines how blending/mixing clips behaves in the inspector panel
        public ClipCaps clipCaps => ClipCaps.None;

        public override Playable CreatePlayable(PlayableGraph graph, GameObject owner)
        {
            // Instantiates the runtime logic block
            var playable = ScriptPlayable<LightGIValueBehaviour>.Create(graph);
            LightGIValueBehaviour behaviour = playable.GetBehaviour();

            // Pass serialized values from the Inspector into the runtime instance
            behaviour.textGIParam = textGIParam;

            return playable;
        }
    }
}