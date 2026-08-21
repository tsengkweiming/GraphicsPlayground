using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace VJ.Midi
{
    public interface IKontrollable {

        void NoteOn(int note);
        void NoteOff(int note);
        void Knob(int knobNumber, float knobValue);
    }
}