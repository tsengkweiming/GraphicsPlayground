#ifndef QUAD_TREE_INCLUDED
#define QUAD_TREE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#define MIN_DIVISIONS 4.0
#define MAX_ITERATIONS 6
#define SAMPLES_PER_ITERATION 30

// A deterministic 2D hash. Keeping the quad center as the seed means
// every pixel in a quad uses the same sample locations.
float2 Hash22(float2 p)
{
    float n = sin(dot(p, float2(41.0, 289.0)));
    return frac(float2(262144.0, 32768.0) * n);
}

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
        float2 randomPoint = Hash22(center + float2(sampleIndex, 0.0)) - 0.5;
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


#endif
