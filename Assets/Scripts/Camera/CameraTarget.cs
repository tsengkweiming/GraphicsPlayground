using System.Collections;
using System.Collections.Generic;

using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace VJ.CameraMovement
{

    [System.Serializable]
    public class CameraTargetLocation
    {
        public string Label { get { return label; } }
        public Vector3 Position { get { return position; } }
        public float Distance {get { return distance; } }

        [SerializeField] protected string label;
        [SerializeField] protected Vector3 position;
        [SerializeField] protected float distance = 30f;
    }

    [System.Serializable]
    public class LazyNoise
    {
        [SerializeField] protected float valueMin, valueMax;
        [SerializeField] protected float scale;

        public float Value(float x, float y)
        {
            return Mathf.Lerp(valueMin, valueMax, Mathf.PerlinNoise(x * scale, y * scale));
        }
    }

    public class CameraTarget : MonoBehaviour {

        public Vector3 Position
        {
            get { return locations[current].Position; }
        }

        public float Distance
        {
            get { return distance + distanceNoise.Value(Time.timeSinceLevelLoad, 0f); }
        }

        [SerializeField] List<CameraTargetLocation> locations;
        [SerializeField] protected int current;
        [SerializeField] protected LazyNoise distanceNoise;
        [SerializeField] protected float distance;

        void Start () {
            current = Mathf.Clamp(current, 0, locations.Count - 1);
            var location = locations[current];
            transform.position = location.Position;
            distance = location.Distance;
        }
        
        void Update () {
            current = Mathf.Clamp(current, 0, locations.Count - 1);
            var location = locations[current];

            var dt = Time.deltaTime;
            var p = Vector3.Lerp(transform.position, location.Position, dt);
            transform.position = p;
            distance = Mathf.Lerp(distance, location.Distance, dt);
        }

        protected void OnDrawGizmos()
        {
            Gizmos.color = Color.green;
            locations.ForEach(loc => {
#if UNITY_EDITOR
                Handles.Label(loc.Position, loc.Label);
#endif
                Gizmos.DrawWireSphere(loc.Position, 1f);
            });
        }
    }

}


