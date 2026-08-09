#ifndef PATTERN_INCLUDED
#define PATTERN_INCLUDED
#include <HLSLSupport.cginc>
#include "Assets/Shaders/Common/Random.hlsl"

// Scalar masks are black-ink coverage: 0 = no ink, 1 = full ink.
// Keeping this separate from RGB output makes procedural darkness explicit.
float pattern_circle_mask(float2 uv, float num, float radius, float t)
{
    float2 tiledUv = frac(uv * num + float2(t, 0.0));
    return 1.0 - step(radius, distance(tiledUv, float2(0.5, 0.5)));
}

float pattern_random_mask(float2 uv, float scale, float seed, float darkness)
{
    float2 cell = floor(uv * scale);
    return step(hash2d(cell + seed), saturate(darkness));
}

float pattern_line(float2 uv, float2 range)
{
    return step(range.x, uv.x) * step(range.y, 1.0-uv.x);
}

float pattern_radius(float2 uv, float radius)
{
    // fixed radius = 0.4;
    fixed r = distance(uv, fixed2(0.5,0.5));
    return step(radius, r);
}

float pattern_ring(float2 uv, float num, float t = 0)
{
    fixed len = distance(uv, fixed2(0.5,0.5)) + t;
    return step(0.9, sin(len*num));
}

float pattern_stripe(float2 uv, float num, float t = 0)
{
    return step(0, sin(num*uv.x+t));
}

float pattern_grid(float2 uv, float num)
{
    fixed2 v = step(0,sin(num*uv))*0.5;
    return frac(v.x+v.y)*2;
}

float pattern_rect(float2 uv, fixed2 size)
{
    fixed2 leftbottom = fixed2(0.5,0.5) - size * 0.5;
    fixed2 uv1 = step(leftbottom, uv);
    uv1 *= step(leftbottom, 1-uv);
    return uv1.x*uv1.y;
}

float3 pattern_circles(float2 uv, float num = 3.0, float size = 0.35, float t = 0.0, float special = 0)
{
    // 1. Scale UV grid
    float2 st = uv * num;
    st.x += t;

    // 2. Identify global tile index and local tile UVs
    float2 tileIndex = floor(st);
    float2 localUV   = frac(st);

    // 3. Circle mask for current tile (1.0 inside, 0.0 outside)
    float len = distance(localUV, float2(0.5, 0.5));
    float circleMask = 1.0 - step(size, len);

    // ------------------------------------------------------------------
    // Wrap tile indices modulo 3.0 so the 3x3 pattern repeats infinitely
    // ------------------------------------------------------------------
    // fmod handles negative coordinates smoothly when combined with + 3.0
    float2 patternPos = fmod(fmod(tileIndex, num) + num, num); 

    // Check if tile is at (1.0, 1.0) inside its 3x3 group
    float isCenterCircle = step(0.9, patternPos.x) * step(patternPos.x, 1.1) *
                           step(0.9, patternPos.y) * step(patternPos.y, 1.1);

    // 4. Color assignment
    float3 circleColor = lerp(0.0, float3(1.0, 0.0, 0.0), step(0.5, special) * isCenterCircle);
    float3 backgroundColor = 1.0;

    return lerp(backgroundColor, circleColor, circleMask);
}

// float pattern_circles(float2 uv, float num = 3, float size = 0.35, float t = 0)
// {
//     fixed2 st = uv * num;
//     st.x += t;
//     st = frac(st);
//
//     fixed len = distance(st,fixed2(0.5,0.5)) + 0;
//     return step(size, len);
// }
#endif
