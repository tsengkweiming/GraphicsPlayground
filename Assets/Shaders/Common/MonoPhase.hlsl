#ifndef _MONO_PHASE_INCLUDED_
#define _MONO_PHASE_INCLUDED_

#include "Assets/Shaders/Common/Random.hlsl"
#include "Assets/Shaders/Common/Transform.hlsl"

float _PhaseSpeed;

float mono_phase(float2 uv, float t)
{
    // ------------------------------------------------------------------
    // 1. TIMING & RANDOM SEED SETUP
    // ------------------------------------------------------------------
    float time = t * _PhaseSpeed;

    float loopIndex = floor(time); // Integer loop counter (1, 2, 3...)
    float progress  = frac(time); // Local loop progress [0.0 to 1.0]

    // Generate unique random values per loop iteration
    float rand1 = hash11(loopIndex * 12.345);
    float rand2 = hash11(loopIndex * 67.890);
    float rand3 = hash11(loopIndex * 99.123);
    float rand4 = hash11(loopIndex * 45.678);

    // ------------------------------------------------------------------
    // 2. PROCEDURAL VARIATIONS PER LOOP
    // ------------------------------------------------------------------
    // Randomize split position between 0.35 and 0.67
    float splitPosition = lerp(0.5, 0.99, rand1);

    // Randomize pivot point near the center [0.3 to 0.7]
    float2 pivotOffset = float2(lerp(0.3, 0.7, rand2), lerp(0.3, 0.7, rand3));

    // Choose 1 of 4 main directions (0: Left->Right, 1: Right->Left, 2: Bottom->Top, 3: Top->Bottom)
    int slideDir = int(floor(rand4 * 4.0));

    // Randomize rotation: randomly choose +90deg or -90deg (1.57 radians)
    float targetAngle = rand1 > 0.5 ? 1.5708 : -1.5708;

    // ------------------------------------------------------------------
    // 3. PHASE TIMING (Branchless)
    // ------------------------------------------------------------------
    // Phase 1: Slide (0.0 to 0.4)
    float slideT = clamp(progress / 0.4, 0.0, 1.0);
    slideT = smoothstep(0.0, 1.0, slideT);

    // Phase 2: Hold briefly (0.4 to 0.5)

    // Phase 3: Rotate forward (0.5 to 0.8)
    float rotForwardT = clamp((progress - 0.5) / 0.3, 0.0, 1.0);
    rotForwardT = smoothstep(0.0, 1.0, rotForwardT);

    // Phase 4: Rotate back to origin (0.8 to 1.0)
    float rotBackT = clamp((progress - 0.8) / 0.2, 0.0, 1.0);
    rotBackT = smoothstep(0.0, 1.0, rotBackT);

    // Net rotation angle over time
    float currentAngle = targetAngle * rotForwardT - targetAngle * rotBackT;

    // ------------------------------------------------------------------
    // 4. COORDINATE TRANSFORMATIONS
    // ------------------------------------------------------------------
    // A. Apply Directional Slide Axis
    float2 slideUV = uv;
    if (slideDir == 1) slideUV.x = 1.0 - uv.x; // Right -> Left
    if (slideDir == 2) slideUV.x = uv.y;       // Bottom -> Top
    if (slideDir == 3) slideUV.x = 1.0 - uv.y; // Top -> Bottom

    // B. Apply Pivot Rotation
    float2 centeredUV = slideUV - pivotOffset;
    float2 rotatedUV  = mul(rotate2D(currentAngle), centeredUV) + pivotOffset;

    // ------------------------------------------------------------------
    // 5. COLOR EVALUATION
    // ------------------------------------------------------------------
    // Slide boundary threshold moves during Phase 1
    float currentEdge = slideT * splitPosition;

    // Mask for slide phase
    float slideColor = step(slideUV.x, currentEdge);

    // Mask for rotation phase
    float rotateColor = step(rotatedUV.x, splitPosition);

    // Blend seamlessly across time phases
    float phaseSelect = step(0.4, progress);
    return lerp(slideColor, rotateColor, phaseSelect);
}

#endif // _MONO_PHASE_INCLUDED_
