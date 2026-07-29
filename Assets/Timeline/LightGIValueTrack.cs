using UnityEngine;
using UnityEngine.Timeline;

namespace Timeline
{
    // Binds this entire track exclusively to your target component class type
    [TrackColor(0.4f, 0.7f, 0.9f)]
    [TrackBindingType(typeof(ProceduralTextGIController))]
    [TrackClipType(typeof(LightGIValueAsset))]
    public class LightGIValueTrack : TrackAsset
    {
        // Left empty: bindings & asset association metadata handled via attributes
    }
}