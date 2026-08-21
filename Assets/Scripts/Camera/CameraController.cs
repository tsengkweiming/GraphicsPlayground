using System;
using UnityEngine;
using VJ.Midi;
using Random = UnityEngine.Random;

namespace VJ.CameraMovement
{
    [Serializable]
    public class CameraControllerParam
    {
        public Vector3 offset;
        [Range(0,5.0f)] public float speed = 1f;
        [Range(0,5.0f)]  public float speedMin = 0.1f;
        [Range(0,5.0f)]  public float speedMax = 2f;
        [Range(0,1.0f)] public float distance = 0.5f;
        public float distanceMin = -20f;
        public float distanceMax = 50f;
        [Range(0,1.0f)] public float angle = 0.5f;
        public float angleMin = -Mathf.PI * 0.25f;
        public float angleMax = Mathf.PI * 0.25f;
    }
    public class CameraController : MonoBehaviour, IKontrollable, MIDIUser {

        [SerializeField] protected InputType midiInputType;
        [SerializeField] protected CameraTarget target;
        [SerializeField] protected PolarCoordinate polar;
        [SerializeField] protected CameraControllerParam param;
        [SerializeField] protected Vector3 offset;
        [SerializeField] protected bool polarDirection;
        
        protected float _distance, _angle;

        public CameraControllerParam Param { get => param; set => param = value; }

        void Start () {
            _distance = param.distance;
            _angle = param.angle;
        }
        
        void Update () {
            var dt = Time.deltaTime;
            var dtt = dt * param.speed * (polarDirection ? 1f : -1f);
            polar.Horizontal(dtt);
            Apply(1f);

            _angle = Mathf.Lerp(_angle, param.angle, dt);
            _distance = Mathf.Lerp(_distance, param.distance, dt);
        }

        private void Apply(float dt)
        {
            var ct = polar.Cartesian(target.Distance + Mathf.Lerp(param.distanceMin, param.distanceMax, _distance), Mathf.Lerp(param.angleMin, param.angleMax, _angle));
            var to = ct + target.transform.position + param.offset;
            transform.position = Vector3.Lerp(transform.position, to, dt);
            Look();
        }

        protected void Look()
        {
            transform.LookAt(target.transform.position);
        }

        public void Randomize()
        {
            param.speed = Mathf.Lerp(param.speedMin, param.speedMax, Random.value);
            polarDirection = !polarDirection;
            polar.Move(Random.Range(0f, Mathf.PI * 0.5f), Random.Range(0f, Mathf.PI * 2f));
        }

        public void NoteOn(int note)
        {
            switch(note)
            {
                case 39:
                    Randomize();
                    break;
                case 55:
                    break;
                case 71:
                    break;
            }
        }

        public void NoteOff(int note)
        {
        }

        public void Knob(int knobNumber, float knobValue)
        {
            switch(knobNumber)
            {
                case 7:
                    // update distance
                    param.distance = knobValue;
                    break;

                case 23:
                    // update angle
                    param.angle = knobValue;
                    break;
            }
        }

        public void OnReceiveNote(InputType type)
        {
            if (midiInputType == type)
            {
                Randomize();
            }
        }

        public void OnReceiveControl(InputType type, float value)
        {
            // throw new NotImplementedException();
        }
    }

}


