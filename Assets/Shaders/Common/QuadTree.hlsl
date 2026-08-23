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
    float size)
{
    float sampleOffset = size * 0.25;
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
    float size;
    float divisions;
    float brightness;
    int depth;
};

// Finds the leaf containing position using luminance as the stop condition.
// Bright nodes stop at their current size; dark nodes keep dividing until they
// become bright enough or the requested maximum depth is reached.
BrightnessQuadResult FindBrightnessQuadTree(
    Texture2D sourceTexture,
    SamplerState sourceSampler,
    float2 position,
    float minDivisions,
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
    float divisions = result.divisions;
    float quadSize = 1.0 / divisions;

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


#endif
