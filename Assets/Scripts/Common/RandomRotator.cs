using UnityEngine;

public class RandomRotator : MonoBehaviour
{
    public float rotationSpeed = 90f; // degrees per second
    public float intervalMin = 1f;
    public float intervalMax = 3f;
    public Vector3 rotateAxis = Vector3.up;
    
    private float nextChangeTime;
    private float currentDirection;

    void Start()
    {
        ScheduleNextRotation();
    }

    void Update()
    {
        // Rotate around Y axis
        var rotate = rotateAxis * (currentDirection * rotationSpeed * Time.deltaTime);
        transform.Rotate(rotate.x, rotate.y, rotate.z);

        // Check if it's time to change direction
        if (Time.time >= nextChangeTime)
        {
            ScheduleNextRotation();
        }
    }

    void ScheduleNextRotation()
    {
        currentDirection = Random.value < 0.5f ? -1f : 1f;
        nextChangeTime = Time.time + Random.Range(intervalMin, intervalMax);
    }
}
