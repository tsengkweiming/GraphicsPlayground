using System;
using RosettaUI;
using UnityEngine;

namespace RosettaSetting
{
    public class TextGIControllerSetting : MonoBehaviour, IElementCreator
    {
        [SerializeField] private ProceduralTextGIController textGIController;
        private TextGIParam _textGIParam = new ();

        private void OnEnable()
        {
            _textGIParam = textGIController.TextGIParam;
        }

        private void ApplySetting()
        {
            textGIController.TextGIParam = _textGIParam;
        }
        
        public Element CreateElement(LabelElement label)
        {
            return UI.Field(() => _textGIParam).RegisterValueChangeCallback(ApplySetting);
        }
    }
}