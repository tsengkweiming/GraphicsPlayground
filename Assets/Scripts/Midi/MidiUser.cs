namespace VJ.Midi
{
    public interface MIDIUser
    {
        void OnReceiveNote(InputType type);
        void OnReceiveControl(InputType type, float value);
    }
}