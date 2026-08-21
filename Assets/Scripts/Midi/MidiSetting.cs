using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace VJ.Midi
{

    [CreateAssetMenu(fileName = "MidiSetting", menuName = "Common/MidiSetting", order = 1)]
    public class MidiSetting : ScriptableObject
    {
        public string productName = "nanoPAD2";
        public List<MIDIData> data;

    }
    [System.Serializable]
    public class MIDIData
    {
        public InputType type;
        public int number;
    }

    public enum InputType
    {
        Note1,
        Note2,
        Note3,
        Note4,
        Note5,
        Note6,
        Note7,
        Note8,
        Note9,
        Note10,
        Note11,
        Note12,
        Note13,
        Note14,
        Note15,
        Note16,
        Note17,
        Note18,
        Note19,
        Note20,
        Note21,
        Note22,
        Note23,
        Note24,
        Note25,
        Note26,
        Note27,
        Note28,
        Note29,
        Note30,
        Note31,
        Note32,
        Note33,
        Note34,
        Note35,
        Note36,
        Note37,
        Note38,
        Note39,
        Note40,
        Control1,
        Control2,
        Control3,
        Control4,
        Control5,
        Control6,
        Control7,
        Control8,
        Control9,
        Control16,
        Null,
    }
}