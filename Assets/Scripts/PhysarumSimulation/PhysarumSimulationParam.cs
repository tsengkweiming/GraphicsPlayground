using UnityEngine;

public class PhysarumSimulationParam : ParmeterController<PhysarumSimulationParam>
{
    public enum Pattern
    {
        OrganicVeins,
        CoralGrowth,
        NeuralMesh,
        OrbitBloom,
        CellularFans
    }

    public enum SpawnShape
    {
        Random,
        Disc,
        Ring,
        HorizontalBand
    }

    public enum DisplayMode
    {
        Trail,
        Particles,
        TrailAndParticles
    }

    [System.Serializable]
    public struct SignalCurve
    {
        [Tooltip("Value used where the sensed trail is zero.")]
        public float constant;

        [Tooltip("Amount added as the sensed trail approaches one. May be negative.")]
        public float response;

        [Min(0.01f)]
        [Tooltip("Shape of the response to sensed trail. One is linear.")]
        public float exponent;

        public SignalCurve(float constant, float response, float exponent)
        {
            this.constant = constant;
            this.response = response;
            this.exponent = exponent;
        }
    }
    
    public Pattern selectedPattern = Pattern.OrganicVeins;
    public Pattern appliedPattern = Pattern.OrganicVeins;
    [Header("Simulation")]
    public Vector2Int resolution = new Vector2Int(1024, 1024);
    [Min(1024)] public int agentCount = 262144;
    [Range(1, 8)] public int iterationsPerFrame = 2;
    [Min(0)] public int seed = 1337;
    public bool paused;

    public SpawnShape spawnShape = SpawnShape.Disc;
    public SpawnShape initializedSpawnShape = SpawnShape.Disc;
    [Header("Initial Distribution")]
    public Vector2 spawnCenter = new Vector2(0.5f, 0.5f);
    [Range(0.01f, 1f)] public float spawnRadius = 0.82f;
    [Range(0.001f, 0.5f)] public float spawnThickness = 0.08f;

    [Header("Trail-dependent Behaviour (distances are pixels, angles are degrees)")]
    public SignalCurve sensorDistance = new SignalCurve(10f, 0f, 1f);
    public SignalCurve sensorAngle = new SignalCurve(42f, 0f, 1f);
    public SignalCurve rotationAngle = new SignalCurve(28f, 0f, 1f);
    public SignalCurve moveDistance = new SignalCurve(1.25f, 0f, 1f);

    [Header("Sensing")]
    [Tooltip("Samples the response-driving trail this many pixels ahead of each agent.")]
    public float responseProbeForwardOffset;
    [Tooltip("World-up pixel offset for the response-driving trail sample.")]
    public float responseProbeVerticalOffset;
    [Min(0f)] public float sensedValueScale = 0.7f;
    public bool bilinearSensing = true;
    [Range(0f, 30f)] public float turnNoiseDegrees = 1.5f;
    [Range(0f, 0.02f)] public float respawnChance;

    [Header("Trail")]
    [Range(0f, 1f)] public float diffusion = 0.9f;
    [Range(0.8f, 0.9999f)] public float decay = 0.965f;
    [Min(0f)] public float depositStrength = 0.28f;
    [Range(1, 256)] public int depositCountLimit = 64;
    [Min(0.01f)] public float trailValueLimit = 12f;

    [Header("Appearance")]
    public DisplayMode displayMode = DisplayMode.TrailAndParticles;
    public Color backgroundColor = new Color(0.003f, 0.005f, 0.012f, 1f);
    public Color shadowColor = new Color(0.02f, 0.08f, 0.16f, 1f);
    public Color midColor = new Color(0.1f, 0.85f, 0.75f, 1f);
    public Color highlightColor = new Color(1f, 0.75f, 0.2f, 1f);
    [Min(0f)] public float trailExposure = 0.55f;
    [Min(0f)] public float particleExposure = 1.4f;
    [Range(0.1f, 3f)] public float contrast = 0.75f;
    [Range(0.05f, 0.95f)] public float colorSplit = 0.48f;
    [Range(0f, 1f)] public float particleHighlight = 0.7f;
    
    public override void CopyFrom(PhysarumSimulationParam other)
    {
        throw new System.NotImplementedException();
    }

    public override void MoveTowards(PhysarumSimulationParam target, float t)
    {
        throw new System.NotImplementedException();
    }

    public override bool Approximately(PhysarumSimulationParam other)
    {
        throw new System.NotImplementedException();
    }
}
