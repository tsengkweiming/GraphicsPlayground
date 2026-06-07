using UnityEngine;

public class RandomRotator : MonoBehaviour
{
    public float rotationSpeed = 90f; // degrees per second
    public float intervalMin = 1f;
    public float intervalMax = 3f;

    private float nextChangeTime;
    private float currentDirection;

    void Start()
    {
        ScheduleNextRotation();
    }

    void Update()
    {
        // Rotate around Y axis
        transform.Rotate(0f, currentDirection * rotationSpeed * Time.deltaTime, 0f);

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
