using UnityEngine;

namespace VJ.Midi
{
    public class GameObjectEnabler : MonoBehaviour, MIDIUser
    {
        public InputType midiInputType;
        public GameObject targetGO;

        public void OnReceiveNote(InputType type)
        {
            if (midiInputType == type)
            {
                var state = targetGO.activeSelf;
                targetGO.SetActive(!state);
            }
        }

        public void OnReceiveControl(InputType type, float value)
        {
            // throw new System.NotImplementedException();
        }
    }

}