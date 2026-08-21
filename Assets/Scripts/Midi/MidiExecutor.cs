using UnityEngine;
using VJ.Midi;

public class MidiExecutor : MonoBehaviour, MIDIUser
{
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnReceiveNote(InputType type)
    {
        throw new System.NotImplementedException();
    }

    public void OnReceiveControl(InputType type, float value)
    {
        throw new System.NotImplementedException();
    }
}
