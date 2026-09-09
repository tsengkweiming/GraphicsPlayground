using System;
using System.Collections.Generic;
using extOSC;
using UnityEngine;

namespace Osc
{
    public class ExternalOscReceiver : OscReceiver
    {
        [SerializeField] private RandomGameObjectActivator _randomGameObjectActivator;
        
        private Dictionary<string, Action<List<string>>> _syncActionMap = new();
        
        private readonly Dictionary<string, Action<ExternalOscReceiver, List<string>>> _oscCallBacks =
            new()
            {
                { "/scene", (self, msg) => self.OnSceneTriggered(msg) },
            };

        private void Awake()
        {
            foreach (var (address, action) in _oscCallBacks)
            {
                _syncActionMap[address] = msg => action(this, msg);
                Bind(address, message => OnReceivedMessage(message, _syncActionMap[address]));
            }
        }

        private void OnSceneTriggered(List<string> msg)
        {
            if (msg.Count > 0)
            {
                Debug.Log($"Received SceneName: {msg[0]}");
            }
            if (msg.Count > 1 && int.TryParse(msg[1], out int oscId))
            {
                StageController.Instance.SetStage(oscId);
                _randomGameObjectActivator.SetRandomObjects();
            }
            if (msg.Count > 2 && int.TryParse(msg[2], out int vfxSwitch))
            {
                StageController.Instance.SetTestStage(vfxSwitch > 0);
            }
            if (msg.Count > 3 && int.TryParse(msg[3], out int textMode))
            {
                if(textMode == 1)
                    _randomGameObjectActivator.SetRandomObjects();
                
                _randomGameObjectActivator.enabled = textMode != 2;
            }
        }
        
        private void OnReceivedMessage(OSCMessage message, Action<List<string>> action)
        {
            if (!_param.IsActive)
                return;

            var values = message.Values;
            var msg = new List<string>(values.Count);
            foreach (var value in values)
            {
                msg.Add(extOSCHelper.GetValueByType(value).ToString());
            }
            action.Invoke(msg);
            UpdateLog(message.Address, string.Join(", ", msg));
        }
    }
}
