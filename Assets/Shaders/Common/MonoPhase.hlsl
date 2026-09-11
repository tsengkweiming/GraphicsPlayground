#ifndef _MONO_PHASE_INCLUDED_
#define _MONO_PHASE_INCLUDED_

#include "Assets/Shaders/Common/Random.hlsl"

float _PhaseSpeed;
float _MonoAsciiRatio;

float mono_phase(float2 uv, float t)
{
    float time = t * _PhaseSpeed;
    float loopIndex = floor(time);
    float progress = frac(time);
    float asciiRatio = saturate(_MonoAsciiRatio);

    // The endpoints are intentional: they make the control useful for
    // animation blending as well as for static looks.
    if (asciiRatio <= 0.0001)
        return 0.0;
    if (asciiRatio >= 0.9999)
        return 1.0;

    // Pick a new random fill direction once per loop.
    float randomDirection = hash11(loopIndex * 45.678);
    int slideDir = (int)floor(randomDirection * 4.0);

    // Reserve a short transition and divide the remaining time between the
    // source hold and ASCII hold. At 0.5 both stable modes last equally long.
    const float transitionDuration = 0.2;
    float stableDuration = 1.0 - transitionDuration;
    float sourceHold = stableDuration * (1.0 - asciiRatio);
    float fillT = smoothstep(
        sourceHold,
        sourceHold + transitionDuration,
        progress);
    float currentEdge = fillT;

    float2 slideUV = uv;
    if (slideDir == 1) slideUV.x = 1.0 - uv.x; // Right -> Left
    if (slideDir == 2) slideUV.x = uv.y;       // Bottom -> Top
    if (slideDir == 3) slideUV.x = 1.0 - uv.y; // Top -> Bottom

    return step(slideUV.x, currentEdge);
}

#endif // _MONO_PHASE_INCLUDED_
