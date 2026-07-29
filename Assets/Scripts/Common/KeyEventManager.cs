using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace Common
{
    public class KeyEventManager : MonoBehaviour
    {

        [System.Serializable]
        public class KeyEventSet
        {
            public bool       enabled = true;
            public string     label;
                              
            public KeyCode    keyCode;
                              
            public bool       ctrl;
            public bool       alt;
            public bool       shift;
            
            public UnityEvent func;
        }
        
        public bool ExportDebugLogOnAwake = true;
        
        [SerializeField]
        List<KeyEventSet> _keyEvents = new();

        bool _isPressedLeftCtrl  = false;
        bool _isPressedLeftAlt   = false;
        bool _isPressedLeftShift = false;

        bool _isPressedRightCtrl  = false;
        bool _isPressedRightAlt   = false;
        bool _isPressedRightShift = false;

        private void Awake()
        {
            if (ExportDebugLogOnAwake)
            {
                Debug.Log("==================== KEY EVENT ====================>");
                for (var i = 0; i < _keyEvents.Count; i++)
                {
                    Debug.LogFormat("{0} : {1}", _keyEvents[i].label, _keyEvents[i].keyCode.ToString());
                }
                Debug.Log("<===================================================");
            }
        }

        void Update()
        {
            if (Input.GetKeyDown(KeyCode.LeftControl))
                _isPressedLeftCtrl   = true;
            if (Input.GetKeyDown(KeyCode.LeftAlt))
                _isPressedLeftAlt    = true;
            if (Input.GetKeyDown(KeyCode.LeftShift))
                _isPressedLeftShift  = true;

            if (Input.GetKeyDown(KeyCode.RightControl))
                _isPressedRightCtrl  = true;
            if (Input.GetKeyDown(KeyCode.RightAlt))
                _isPressedRightAlt   = true;
            if (Input.GetKeyDown(KeyCode.RightShift))
                _isPressedRightShift = true;

            if (Input.GetKeyUp(KeyCode.LeftControl))
                _isPressedLeftCtrl   = false;
            if (Input.GetKeyUp(KeyCode.LeftAlt))
                _isPressedLeftAlt    = false;
            if (Input.GetKeyUp(KeyCode.LeftShift))
                _isPressedLeftShift  = false;

            if (Input.GetKeyUp(KeyCode.RightControl))
                _isPressedRightCtrl  = false;
            if (Input.GetKeyUp(KeyCode.RightAlt))
                _isPressedRightAlt   = false;
            if (Input.GetKeyUp(KeyCode.RightShift))
                _isPressedRightShift = false;


            var count = _keyEvents.Count;

            for (var i = 0; i < count; i++)
            {
                if (_keyEvents[i].enabled == true)
                {
                    if (Input.GetKeyUp(_keyEvents[i].keyCode))
                    {
                        var bCtrl = _keyEvents[i].ctrl == false ? true : (_isPressedLeftCtrl || _isPressedRightCtrl);
                        var bAlt = _keyEvents[i].alt == false ? true : (_isPressedLeftAlt || _isPressedRightAlt);
                        var bShift = _keyEvents[i].shift == false ? true : (_isPressedLeftShift || _isPressedRightShift);

                        if (bCtrl && bAlt && bShift)
                        {
                            if (_keyEvents[i].func != null)
                            {
                                _keyEvents[i].func.Invoke();
                            }
                        }
                    }
                }
            }
        }
    }
}
