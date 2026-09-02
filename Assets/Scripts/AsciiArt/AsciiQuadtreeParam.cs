using UnityEngine;

[System.Serializable]
public class AsciiQuadtreeParam : ParmeterController<AsciiQuadtreeParam>
{
    [Range(1, 10)] public int patternCount = 4;
    [Range(0, 10)] public int textureCount = 4;
    public Color patternColor = Color.black;
    public Color patternBackgroundColor = Color.white;
        
    [Header("Grid")]
    [Min(1)] public int resolution = 60;
    [Min(0.01f)] public float gridWidth = 16.1f;
    [Min(0.01f)] public float gridHeight = 10f;
    [Range(0f, 0.9f)] public float cellGap = 0f;
    public Color lineColor = Color.black;
    public float lineWidth = 1.0f;
    [Range(0f, 1f)] public float lineStrength = 0f;
    public float phaseSpeed = 0.1f;
    public float posterizeLevel = 5f;
    [Range(0.1f, 5)] public float gamma = 1f;
    [Range(0, 4)] public float contrast = 1.2f;
    [Range(-1, 1)] public float brightness = 0f;
        
    public Vector3 hsvAdjust = Vector3.one;
    [Range(0f, 1f)] public float colorTexUvIndex = 1f;

    [Header("Adaptive Quadtree")]
    [Min(1)] public int minimumShortAxisDivisions = 4;
    [Range(1, 8)] public int maximumDepth = 6;
    [Range(0f, 1f)] public float brightnessStop = 0.5f;

    [Header("Object Depth")]
    [Min(0.01f)] public float thickness = 0.2f;
    [Range(-50f, 50f)] public float randomDepthOffset = 0f;

    [Header("Geometry Motion")]
    [Range(0f, 1f)] public float motionActiveThreshold = 1f;
    [Min(0f)] public float depthMotionAmplitude = 0f;
    [Min(0f)] public float depthMotionSpeed = 1f;
    [Range(-180f, 180f)] public float rotationAmplitude = -30f;

    [Header("Curl Noise Motion")]
    public float curlNoiseAmplitude = 0f;
    [Min(0f)] public float curlNoiseScale = 2f;
    public float curlNoiseSpeed = 0.1f;
    public Vector3 curlNoiseDirection = new (0.3f, 0.2f, 0.1f);
    
    public int activeTextureSetIndex = 0;

    public override void CopyFrom(AsciiQuadtreeParam other)
    {
        if (other == null)
        {
            return;
        }
        
        patternCount = other.patternCount;
        textureCount = other.textureCount;
        patternColor = other.patternColor;
        patternBackgroundColor = other.patternBackgroundColor;
        
        resolution = other.resolution;
        gridWidth = other.gridWidth;
        gridHeight = other.gridHeight;
        cellGap = other.cellGap;
        lineColor = other.lineColor;
        lineWidth = other.lineWidth;
        lineStrength = other.lineStrength;
        phaseSpeed = other.phaseSpeed;
        posterizeLevel = other.posterizeLevel;
        gamma = other.gamma;
        contrast = other.contrast;
        brightness = other.brightness;
        
        hsvAdjust = other.hsvAdjust;
        colorTexUvIndex = other.colorTexUvIndex;
        
        minimumShortAxisDivisions = other.minimumShortAxisDivisions;
        maximumDepth = other.maximumDepth;
        brightnessStop = other.brightnessStop;
        
        thickness = other.thickness;
        randomDepthOffset = other.randomDepthOffset;
        motionActiveThreshold = other.motionActiveThreshold;
        depthMotionAmplitude = other.depthMotionAmplitude;
        depthMotionSpeed = other.depthMotionSpeed;
        rotationAmplitude = other.rotationAmplitude;
        
        curlNoiseAmplitude = other.curlNoiseAmplitude;
        curlNoiseScale  = other.curlNoiseScale;
        curlNoiseSpeed  = other.curlNoiseSpeed;
        curlNoiseDirection = other.curlNoiseDirection;
        
        activeTextureSetIndex = other.activeTextureSetIndex;
    }

    public override void MoveTowards(AsciiQuadtreeParam target, float t)
    {
        if (target == null)
        {
            return;
        }
        
        patternCount = LerpValue(patternCount, target.patternCount, t);
        textureCount = LerpValue(textureCount, target.textureCount, t);
        patternColor = LerpValue(patternColor, target.patternColor, t);
        patternBackgroundColor = LerpValue(patternBackgroundColor, target.patternBackgroundColor, t);
        
        resolution = LerpValue(resolution, target.resolution, t);
        gridWidth = LerpValue(gridWidth, target.gridWidth, t);
        gridHeight = LerpValue(gridHeight, target.gridHeight, t);
        cellGap = LerpValue(cellGap, target.cellGap, t);
        lineColor = LerpValue(lineColor, target.lineColor, t);
        lineWidth = LerpValue(lineWidth, target.lineWidth, t);
        lineStrength = LerpValue(lineStrength, target.lineStrength, t);
        phaseSpeed = LerpValue(phaseSpeed, target.phaseSpeed, t);
        posterizeLevel = LerpValue(posterizeLevel, target.posterizeLevel, t);
        gamma = LerpValue(gamma, target.gamma, t);
        contrast = LerpValue(contrast, target.contrast, t);
        brightness = LerpValue(brightness, target.brightness, t);
        
        hsvAdjust = LerpValue(hsvAdjust, target.hsvAdjust, t);
        colorTexUvIndex  = LerpValue(colorTexUvIndex, target.colorTexUvIndex, t);
        
        minimumShortAxisDivisions = LerpValue(minimumShortAxisDivisions, target.minimumShortAxisDivisions, t);
        maximumDepth = LerpValue(maximumDepth, target.maximumDepth, t);
        brightnessStop = LerpValue(brightnessStop, target.brightnessStop, t);
        thickness = LerpValue(thickness, target.thickness, t);
        randomDepthOffset = LerpValue(randomDepthOffset, target.randomDepthOffset, t);
        motionActiveThreshold = LerpValue(motionActiveThreshold, target.motionActiveThreshold, t);
        depthMotionAmplitude  = LerpValue(depthMotionAmplitude, target.depthMotionAmplitude, t);
        depthMotionSpeed = LerpValue(depthMotionSpeed, target.depthMotionSpeed, t);
        rotationAmplitude  = LerpValue(rotationAmplitude, target.rotationAmplitude, t);
        
        curlNoiseAmplitude = LerpValue(curlNoiseAmplitude, target.curlNoiseAmplitude, t);
        curlNoiseScale  = LerpValue(curlNoiseScale, target.curlNoiseScale, t);
        curlNoiseSpeed  = LerpValue(curlNoiseSpeed, target.curlNoiseSpeed, t);
        curlNoiseDirection = LerpValue(curlNoiseDirection, target.curlNoiseDirection, t);
        
        activeTextureSetIndex = LerpValue(activeTextureSetIndex, target.activeTextureSetIndex, t);
    }

    public override bool Approximately(AsciiQuadtreeParam other)
    {
        if (other == null)
        {
            return false;
        }

        return ApproximatelyValue(patternCount, other.patternCount)
               && ApproximatelyValue(textureCount, other.textureCount)
               && ApproximatelyValue(patternColor, other.patternColor)
               && ApproximatelyValue(patternBackgroundColor, other.patternBackgroundColor)
               && ApproximatelyValue(resolution, other.resolution)
               && ApproximatelyValue(gridWidth, other.gridWidth)
               && ApproximatelyValue(gridHeight, other.gridHeight)
               && ApproximatelyValue(cellGap, other.cellGap)
               && ApproximatelyValue(lineWidth, other.lineWidth)
               && ApproximatelyValue(lineStrength, other.lineStrength)
               && ApproximatelyValue(phaseSpeed, other.phaseSpeed)
               && ApproximatelyValue(posterizeLevel, other.posterizeLevel)
               && ApproximatelyValue(gamma, other.gamma)
               && ApproximatelyValue(contrast, other.contrast)
               && ApproximatelyValue(brightness, other.brightness)
               && ApproximatelyValue(hsvAdjust, other.hsvAdjust)
               && ApproximatelyValue(colorTexUvIndex, other.colorTexUvIndex)
               && ApproximatelyValue(minimumShortAxisDivisions, other.minimumShortAxisDivisions)
               && ApproximatelyValue(maximumDepth, other.maximumDepth)
               && ApproximatelyValue(brightnessStop, other.brightnessStop)
               && ApproximatelyValue(thickness, other.thickness)
               && ApproximatelyValue(randomDepthOffset, other.randomDepthOffset)
               && ApproximatelyValue(motionActiveThreshold, other.motionActiveThreshold)
               && ApproximatelyValue(depthMotionAmplitude, other.depthMotionAmplitude)
               && ApproximatelyValue(depthMotionSpeed, other.depthMotionSpeed)
               && ApproximatelyValue(rotationAmplitude, other.rotationAmplitude)
               && ApproximatelyValue(curlNoiseAmplitude, other.curlNoiseAmplitude)
               && ApproximatelyValue(curlNoiseScale, other.curlNoiseScale)
               && ApproximatelyValue(curlNoiseSpeed, other.curlNoiseSpeed)
               && ApproximatelyValue(curlNoiseDirection, other.curlNoiseDirection)
               && ApproximatelyValue(activeTextureSetIndex, other.activeTextureSetIndex)
            ;
    }
}
