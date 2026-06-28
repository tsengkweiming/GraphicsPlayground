#ifndef __PROCEDURAL_TEXT_INCLUDED__
#define __PROCEDURAL_TEXT_INCLUDED__

#include "../Common/SDF.hlsl"

#ifndef PROCEDURAL_TEXT_MAX_TEXTS
#define PROCEDURAL_TEXT_MAX_TEXTS 32
#endif
#ifndef PROCEDURAL_TEXT_MAX_CHARS
#define PROCEDURAL_TEXT_MAX_CHARS 256
#endif
#ifndef PROCEDURAL_TEXT_MAX_DOTS_PER_CHAR
#define PROCEDURAL_TEXT_MAX_DOTS_PER_CHAR 128
#endif
#ifndef PROCEDURAL_TEXT_RANDOM_ROTATION_MAX
#define PROCEDURAL_TEXT_RANDOM_ROTATION_MAX 0.22
#endif
#ifndef PROCEDURAL_TEXT_RANDOM_ROTATION_SPEED
#define PROCEDURAL_TEXT_RANDOM_ROTATION_SPEED 8.0
#endif
#ifndef PROCEDURAL_TEXT_RANDOM_POSITION_MAX
#define PROCEDURAL_TEXT_RANDOM_POSITION_MAX 8.0
#endif
#ifndef PROCEDURAL_TEXT_RANDOM_POSITION_SPEED
#define PROCEDURAL_TEXT_RANDOM_POSITION_SPEED 1.0
#endif

// ─── Structs ────────────────────────────────────────────────────
struct Dot2d
{
    float2 position;
    float  curvature;    // 0: straight, >0: curved
    int    startOfNext;  // kept  Euseful for curve stepping
    float4 color;
};

struct Character
{
    int    dotOffset;    // first index into _DotBuffer
    int    dotCount;     // how many dots this character owns
    float3 position;
    float3 scale;
};

struct Text
{
    int    charOffset;   // first index into _CharacterBuffer
    int    charCount;
    float3 position;
};

// ─── Data buffers ───────────────────────────────────────────────
StructuredBuffer<Dot2d>     _DotBuffer;
StructuredBuffer<Character> _CharacterBuffer;
StructuredBuffer<Text>      _TextBuffer;

int _DotCount;
int _CharacterCount;
int _TextCount;

float proceduralTextSafeScale(float v)
{
    return abs(v) < 0.0001 ? 1.0 : v;
}

float proceduralTextHash11(float n)
{
    return frac(sin(n * 127.1) * 43758.5453);
}

float proceduralTextPerlin1D(float x)
{
    float i = floor(x);
    float f = frac(x);
    float u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float ga = proceduralTextHash11(i) * 2.0 - 1.0;
    float gb = proceduralTextHash11(i + 1.0) * 2.0 - 1.0;
    return lerp(ga * f, gb * (f - 1.0), u) * 2.0;
}

float2 proceduralTextRotate2D(float2 p, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float proceduralTextCharacterAngle(int textIndex, int charIndex, Character character, float time)
{
    float seed = float(textIndex) * 113.17
               + float(charIndex) * 37.91
               + dot(character.position.xy, float2(0.071, 0.137));
    float noiseX = seed + time * PROCEDURAL_TEXT_RANDOM_ROTATION_SPEED;
    float noise = proceduralTextPerlin1D(noiseX) * 0.72
                + proceduralTextPerlin1D(noiseX * 0.47 + seed * 0.13 + 19.7) * 0.28;
    return clamp(noise, -1.0, 1.0) * PROCEDURAL_TEXT_RANDOM_ROTATION_MAX;
}

float2 proceduralTextCharacterOffset(int textIndex, int charIndex, Character character, float time)
{
    float seed = float(textIndex) * 83.29
               + float(charIndex) * 61.71
               + dot(character.position.xy, float2(0.173, 0.097));
    float noiseX = seed + time * PROCEDURAL_TEXT_RANDOM_POSITION_SPEED;
    float noiseY = seed * 1.37 + 47.3 + time * PROCEDURAL_TEXT_RANDOM_POSITION_SPEED * 0.83;
    float2 noise = float2(
        proceduralTextPerlin1D(noiseX) * 0.74 + proceduralTextPerlin1D(noiseX * 0.41 + 23.1) * 0.26,
        proceduralTextPerlin1D(noiseY) * 0.74 + proceduralTextPerlin1D(noiseY * 0.43 + 71.9) * 0.26
    );

    return clamp(noise, -1.0, 1.0) * PROCEDURAL_TEXT_RANDOM_POSITION_MAX;
}

float2 proceduralTextDotPosition(Dot2d dot, Character character, Text text, float angle, float2 offset)
{
    float2 scale = float2(
        proceduralTextSafeScale(character.scale.x),
        proceduralTextSafeScale(character.scale.y)
    );

    float2 localPos = dot.position * scale;
    float2 pivot = scale * 0.5;
    localPos = proceduralTextRotate2D(localPos - pivot, angle) + pivot;

    return text.position.xy + character.position.xy + offset + localPos;
}

float sdProceduralTextStroke(float2 p, float2 a, float2 b, float curvature, float radius)
{
    float2 ab = b - a;
    float lenAB = length(ab);

    if (lenAB < 0.0001)
    {
        return length(p - a) - radius;
    }

    float curve = clamp(curvature, -2.0, 2.0);
    if (abs(curve) < 0.0001)
    {
        return sdCap2D(p, a, b, radius);
    }

    float sagitta = curve * lenAB * 0.25;
    float sagittaAbs = min(abs(sagitta), lenAB * 0.45);
    float curveSign = sagitta < 0.0 ? -1.0 : 1.0;
    float arcRadius = lenAB * lenAB / max(8.0 * sagittaAbs, 0.0001) + sagittaAbs * 0.5;
    float2 axis = ab / lenAB;
    float2 normal = float2(-axis.y, axis.x) * curveSign;
    float2 center = (a + b) * 0.5 - normal * (arcRadius - sagittaAbs);
    float2 centerToP = p - center;
    float2 localP = float2(dot(centerToP, axis), dot(centerToP, normal));
    float sinA = saturate((lenAB * 0.5) / max(arcRadius, 0.0001));
    float cosA = sqrt(saturate(1.0 - sinA * sinA));

    return sdArc(localP, float2(sinA, cosA), arcRadius, radius);
}

float4 proceduralTextStrokeColor(Dot2d a, Dot2d b)
{
    float4 fallback = float4(1.0, 0.92, 0.72, 1.0);
    float useA = step(0.0001, a.color.a);
    float useB = step(0.0001, b.color.a);
    float4 colorA = lerp(fallback, a.color, useA);
    float4 colorB = lerp(colorA, b.color, useB);
    return colorB;
}

float sdProceduralText2D(float2 p, float radius, float time, out float4 color)
{
    float minD = 1e9;
    color = float4(1.0, 0.92, 0.72, 1.0);

    int textCount = min(max(_TextCount, 0), PROCEDURAL_TEXT_MAX_TEXTS);

    [loop]
    for (int textIndex = 0; textIndex < PROCEDURAL_TEXT_MAX_TEXTS; textIndex++)
    {
        if (textIndex >= textCount) break;

        Text text = _TextBuffer[textIndex];
        int charStart = clamp(text.charOffset, 0, max(_CharacterCount, 0));
        int charEnd = min(charStart + max(text.charCount, 0), _CharacterCount);
        int charLimit = min(charEnd - charStart, PROCEDURAL_TEXT_MAX_CHARS);

        [loop]
        for (int charLocalIndex = 0; charLocalIndex < PROCEDURAL_TEXT_MAX_CHARS; charLocalIndex++)
        {
            if (charLocalIndex >= charLimit) break;

            int charIndex = charStart + charLocalIndex;
            Character character = _CharacterBuffer[charIndex];
            float charAngle = 2 * proceduralTextCharacterAngle(textIndex, charIndex, character, time);
            float2 characterOffset = 50 * proceduralTextCharacterOffset(textIndex, charIndex, character, time);
            int dotStart = clamp(character.dotOffset, 0, max(_DotCount, 0));
            int dotEnd = min(dotStart + max(character.dotCount, 0), _DotCount);
            int segmentLimit = min(max(dotEnd - dotStart - 1, 0), PROCEDURAL_TEXT_MAX_DOTS_PER_CHAR);

            [loop]
            for (int segmentIndex = 0; segmentIndex < PROCEDURAL_TEXT_MAX_DOTS_PER_CHAR; segmentIndex++)
            {
                if (segmentIndex >= segmentLimit) break;

                Dot2d aDot = _DotBuffer[dotStart + segmentIndex];
                if (aDot.startOfNext == 0) continue;

                Dot2d bDot = _DotBuffer[dotStart + segmentIndex + 1];
                float2 posA = proceduralTextDotPosition(aDot, character, text, charAngle, characterOffset);
                float2 posB = proceduralTextDotPosition(bDot, character, text, charAngle, characterOffset);
                float d  = sdProceduralTextStroke(p, posA, posB, aDot.curvature, radius);

                if (d < minD)
                {
                    minD = d;
                    color = proceduralTextStrokeColor(aDot, bDot);
                }
            }
        }
    }

    return minD;
}

//for chinese character maybe use sdf to form the field and use particle?

#endif // __PROCEDURAL_TEXT_INCLUDED__
