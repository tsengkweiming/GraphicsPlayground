#ifndef QUAD_TREE_INCLUDED
#define QUAD_TREE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Common/Random.hlsl"

#define MIN_DIVISIONS 4.0
#define MAX_ITERATIONS 6
#define SAMPLES_PER_ITERATION 30

// Brightness-driven subdivision is deliberately capped because this function
// is evaluated for every fragment. A value of 8 supports the same practical
// depth as the existing variance quadtree while keeping the loop statically
// bounded for the GPU compiler.
#define BRIGHTNESS_QUADTREE_MAX_ITERATIONS 8
#define BRIGHTNESS_QUADTREE_SAMPLE_COUNT 5

// Estimate the average color and RGB variance of one candidate quad.
float4 QuadColorVariation(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 center,
    float size)
{
    float3 samplesBuffer[SAMPLES_PER_ITERATION];
    float3 average = 0.0;

    [unroll]
    for (int i = 0; i < SAMPLES_PER_ITERATION; ++i)
    {
        float sampleIndex = (float)i;
        float2 randomPoint = hash22(center + float2(sampleIndex, 0.0)) - 0.5;
        float3 sampleColor = SAMPLE_TEXTURE2D(
            sourceTexture,
            sourceSampler,
            center + randomPoint * size).rgb;

        average += sampleColor;
        samplesBuffer[i] = sampleColor;
    }

    average /= (float)SAMPLES_PER_ITERATION;

    float3 variance = 0.0;

    [unroll]
    for (int i = 0; i < SAMPLES_PER_ITERATION; ++i)
    {
        variance += samplesBuffer[i] * samplesBuffer[i];
    }

    variance /= (float)SAMPLES_PER_ITERATION;
    variance -= average * average;

    return float4(average, (variance.x + variance.y + variance.z) / 3.0);
}

// Average luminance of a candidate quad. The center plus four interior points
// makes the subdivision decision stable for both broad bright regions and
// small bright details without the cost of a full variance calculation.
float QuadAverageLuminance(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 center,
    float2 size)
{
    float2 sampleOffset = size * 0.25;
    float2 offsets[BRIGHTNESS_QUADTREE_SAMPLE_COUNT] =
    {
        float2(0.0, 0.0),
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0)
    };

    float3 colorSum = 0.0;

    [unroll]
    for (int i = 0; i < BRIGHTNESS_QUADTREE_SAMPLE_COUNT; ++i)
    {
        float2 sampleUv = saturate(center + offsets[i] * sampleOffset);
        colorSum += SAMPLE_TEXTURE2D(sourceTexture, sourceSampler, sampleUv).rgb;
    }

    float3 average = colorSum / (float)BRIGHTNESS_QUADTREE_SAMPLE_COUNT;
    return dot(average, float3(0.299, 0.587, 0.114));
}

struct BrightnessQuadResult
{
    float2 center;
    float2 size;
    float2 divisions;
    float brightness;
    int depth;
};

// Packed result written by the compute evaluator and read by the instanced
// renderer. Keep this layout in sync with the C# GraphicsBuffer stride.
struct QuadTreeLeafData
{
    float2 center;
    float2 size;
    float2 cellCenter;
    float brightness;
    float keep;
};

// Finds the leaf containing position using luminance as the stop condition.
// Bright nodes stop at their current size; dark nodes keep dividing until they
// become bright enough or the requested maximum depth is reached.
BrightnessQuadResult FindBrightnessQuadTree(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 position,
    float2 minDivisions,
    int maxIterations,
    float stopBrightness)
{
    BrightnessQuadResult result;
    result.center = 0.5;
    result.size = 1.0;
    result.divisions = max(round(minDivisions), 1.0);
    result.brightness = 0.0;
    result.depth = 0;

    int safeIterations = clamp(maxIterations, 1, BRIGHTNESS_QUADTREE_MAX_ITERATIONS);
    float threshold = saturate(stopBrightness);
    float2 divisions = result.divisions;
    float2 quadSize = 1.0 / divisions;

    [loop]
    for (int iteration = 0; iteration < BRIGHTNESS_QUADTREE_MAX_ITERATIONS; ++iteration)
    {
        result.center = (floor(position * divisions) + 0.5) / divisions;
        result.size = quadSize;
        result.divisions = divisions;
        result.brightness = QuadAverageLuminance(
            sourceTexture,
            sourceSampler,
            result.center,
            quadSize);
        result.depth = iteration;

        if (iteration + 1 >= safeIterations || result.brightness >= threshold)
            break;

        divisions *= 2.0;
        quadSize *= 0.5;
    }

    return result;
}

// Vertex-stage variant for instanced geometry. Explicit LOD is required because
// vertex shaders do not have fragment derivatives for implicit texture LOD.
float QuadAverageLuminanceLod(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 center,
    float2 size)
{
    float2 sampleOffset = size * 0.25;
    float2 offsets[BRIGHTNESS_QUADTREE_SAMPLE_COUNT] =
    {
        float2(0.0, 0.0),
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0)
    };

    float3 colorSum = 0.0;

    [unroll]
    for (int i = 0; i < BRIGHTNESS_QUADTREE_SAMPLE_COUNT; ++i)
    {
        float2 sampleUv = saturate(center + offsets[i] * sampleOffset);
        colorSum += SAMPLE_TEXTURE2D_LOD(
            sourceTexture,
            sourceSampler,
            sampleUv,
            0.0).rgb;
    }

    float3 average = colorSum / (float)BRIGHTNESS_QUADTREE_SAMPLE_COUNT;
    return dot(average, float3(0.299, 0.587, 0.114));
}

BrightnessQuadResult FindBrightnessQuadTreeLod(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 position,
    float2 minDivisions,
    int maxIterations,
    float stopBrightness)
{
    BrightnessQuadResult result;
    result.center = 0.5;
    result.size = 1.0;
    result.divisions = max(round(minDivisions), 1.0);
    result.brightness = 0.0;
    result.depth = 0;

    int safeIterations = clamp(maxIterations, 1, BRIGHTNESS_QUADTREE_MAX_ITERATIONS);
    float threshold = saturate(stopBrightness);
    float2 divisions = result.divisions;
    float2 quadSize = 1.0 / divisions;

    [loop]
    for (int iteration = 0; iteration < BRIGHTNESS_QUADTREE_MAX_ITERATIONS; ++iteration)
    {
        result.center = (floor(position * divisions) + 0.5) / divisions;
        result.size = quadSize;
        result.divisions = divisions;
        result.brightness = QuadAverageLuminanceLod(
            sourceTexture,
            sourceSampler,
            result.center,
            quadSize);
        result.depth = iteration;

        if (iteration + 1 >= safeIterations || result.brightness >= threshold)
            break;

        divisions *= 2.0;
        quadSize *= 0.5;
    }

    return result;
}

float2 QuadTreeSourceUv(float2 uv, float flipY)
{
    uv.y = lerp(uv.y, 1.0 - uv.y, step(0.5, flipY));
    return uv;
}

float2 QuadTreeMinimumDivisions(float gridAspect, float minimumShortAxisDivisions)
{
    float shortAxis = max(floor(minimumShortAxisDivisions), 1.0);
    float safeAspect = max(gridAspect, 0.0001);
    float2 landscape = float2(
        max(round(shortAxis * safeAspect), 1.0),
        shortAxis);
    float2 portrait = float2(
        shortAxis,
        max(round(shortAxis / safeAspect), 1.0));
    return lerp(portrait, landscape, step(1.0, safeAspect));
}

int QuadTreeMaximumIterations(
    float2 gridSize,
    float2 minimumDivisions,
    float requestedIterations)
{
    // Each iteration doubles both axes. Stop before a leaf can become smaller
    // than the discrete evaluation lattice, which avoids duplicate or empty
    // representative cells at non-power-of-two resolutions.
    float ratioX = max(gridSize.x / max(minimumDivisions.x, 1.0), 1.0);
    float ratioY = max(gridSize.y / max(minimumDivisions.y, 1.0), 1.0);
    float ratio = max(min(ratioX, ratioY), 1.0);
    int resolutionDepth = 1 + (int)floor(log2(ratio));
    int safeRequested = (int)floor(max(requestedIterations, 1.0));
    return min(safeRequested, resolutionDepth);
}

QuadTreeLeafData EvaluateQuadTreeCell(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    uint globalIndex,
    uint columns,
    uint rows,
    float gridAspect,
    float minimumShortAxisDivisions,
    float requestedIterations,
    float stopBrightness,
    float flipY)
{
    QuadTreeLeafData result;
    uint safeColumns = max(columns, 1u);
    uint safeRows = max(rows, 1u);
    float2 gridSize = float2(safeColumns, safeRows);
    uint2 cellId = uint2(globalIndex % safeColumns, globalIndex / safeColumns);
    result.cellCenter = (float2(cellId) + 0.5) / gridSize;

    float2 minimumDivisions = QuadTreeMinimumDivisions(
        gridAspect,
        minimumShortAxisDivisions);
    int maximumIterations = QuadTreeMaximumIterations(
        gridSize,
        minimumDivisions,
        requestedIterations);

    BrightnessQuadResult quad = FindBrightnessQuadTreeLod(
        sourceTexture,
        sourceSampler,
        QuadTreeSourceUv(result.cellCenter, flipY),
        minimumDivisions,
        maximumIterations,
        stopBrightness);

    result.center = QuadTreeSourceUv(quad.center, flipY);
    result.size = quad.size;
    result.brightness = quad.brightness;

    float2 representativeCell = floor(result.center * gridSize);
    float cellDistance = abs(float2(cellId).x - representativeCell.x) +
                         abs(float2(cellId).y - representativeCell.y);
    result.keep = step(cellDistance, 0.5);
    return result;
}


#endif
