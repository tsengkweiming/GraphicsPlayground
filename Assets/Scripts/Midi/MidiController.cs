using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;
using Minis;

namespace VJ.Midi
{
    public class MidiController : MonoBehaviour
    {
        [SerializeField] private MidiSetting setting;

        private Action<InputDevice, InputDeviceChange> inputAction;
        private Action<InputType> noteActions;
        private Action<InputType, float> controlActions;

        private Dictionary<int, InputType> midiMap;

        #region Debug
        public bool IsShow { get; set; }
        public void ShowOrHide() { IsShow = !IsShow; }
        #endregion

        private string midiStatus = "Idle";

        private void Awake()
        {
            midiMap = setting.data.ToDictionary(d => d.number, d => d.type);
            SetupUserActions();
            SetupInputActions();

            InputSystem.onDeviceChange += inputAction;
        }

        private void SetupUserActions()
        {
            var midis = FindObjectsOfTypeAll<MIDIUser>().ToList();
            foreach (var m in midis)
            {
                noteActions    += m.OnReceiveNote;
                controlActions += m.OnReceiveControl;
            }
        }

        private void SetupInputActions()
        {
            inputAction = (device, change) => {
                var midiDevice = device as MidiDevice;
                if (!CheckDevice(midiDevice, change)) return;

                Debug.Log(string.Format("{0} ({1}) {2}",
                    device.description.product, midiDevice.channel, change));

                midiDevice.onWillNoteOn += (note, velocity) => {
                    if (CheckProductName(note.device.description.product))
                    {
                        InputType type;
                        if (CheckRegistration(note.noteNumber, out type))
                        {
                            noteActions?.Invoke(midiMap[note.noteNumber]);
                            midiStatus = $"{midiMap[note.noteNumber]}";
                            Debug.Log($"midiMap{midiStatus}. noteNumber{note.noteNumber}. presseddddd.");
                        }
                        else
                        {
                            Debug.Log($"{note.noteNumber}  hasn't been registered.");
                        }
                    }
                };

                midiDevice.onWillControlChange += (cc, value) => {
                    if (CheckProductName(cc.device.description.product))
                    {
                        InputType type;
                        if (CheckRegistration(cc.controlNumber, out type))
                        {
                            controlActions?.Invoke(midiMap[cc.controlNumber], value);
                            midiStatus = string.Format("{0}:{1:#.00}", midiMap[cc.controlNumber], value);
                            Debug.Log($"midiMap{midiStatus}. controlNumber{cc.controlNumber}. scrolled.");
                        }
                        else
                        {
                            Debug.Log($"{cc.controlNumber} hasn't been registered.");
                        }
                    }
                };

            };
        }

        public List<T> FindObjectsOfTypeAll<T>()
        {
            List<T> results = new List<T>();
            SceneManager.GetActiveScene().GetRootGameObjects().ToList().ForEach(g => results.AddRange(g.GetComponentsInChildren<T>(true)));
            return results;
        }

        private bool CheckDevice(MidiDevice device, InputDeviceChange change)
        {
            return device != null && change == InputDeviceChange.Added;
        }
        private bool CheckProductName(string productName)
        {
            return productName.Contains(setting.productName);
        }
        private bool CheckRegistration(int number, out InputType type)
        {
            return midiMap.TryGetValue(number, out type);
        }

        void OnGUI()
        {
            if (!IsShow) return;

            int w = Screen.width, h = Screen.height;
            var style = GUIStyle.none;
            var size = style.fontSize;

            GUI.Label(new Rect(0, size, w, h), midiStatus, style);
        }

        private void OnDestroy()
        {
            InputSystem.onDeviceChange -= inputAction;
        }
    }
}