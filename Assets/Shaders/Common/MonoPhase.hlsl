#ifndef _MONO_PHASE_INCLUDED_
#define _MONO_PHASE_INCLUDED_

#include "Assets/Shaders/Common/Random.hlsl"

float _PhaseSpeed;

float mono_phase(float2 uv, float t)
{
    float time = t * _PhaseSpeed;
    float loopIndex = floor(time);
    float progress = frac(time);

    // Pick a new random fill direction once per loop.
    float randomDirection = hash11(loopIndex * 45.678);
    int slideDir = (int)floor(randomDirection * 4.0);

    // Fill during the first part of the loop, then hold the completed mode.
    // At the next loop boundary the new direction is selected immediately.
    float fillT = smoothstep(0.0, 1.0, saturate(progress / 0.4));
    float currentEdge = fillT;

    float2 slideUV = uv;
    if (slideDir == 1) slideUV.x = 1.0 - uv.x; // Right -> Left
    if (slideDir == 2) slideUV.x = uv.y;       // Bottom -> Top
    if (slideDir == 3) slideUV.x = 1.0 - uv.y; // Top -> Bottom

    return step(slideUV.x, currentEdge);
}

#endif // _MONO_PHASE_INCLUDED_
