#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDE_BLEND
#define POSTEFFECT_GRAPH_HLSL_INCLUDE_BLEND

#include "Packages/com.team-lab.posteffect-graph/Runtime/Shaders/Color.hlsl"

static const int BlendNone = 0;
static const int BlendAlphaBlend = 10;
static const int BlendAdd = 20;
static const int BlendAddLighter = 21;
static const int BlendSubtract = 30;
static const int BlendDifference = 40;
static const int BlendMultiply = 50;
static const int BlendScreen = 60;
static const int BlendOverlay = 70;
static const int BlendDarken = 80;
static const int BlendLighten = 90;
static const int BlendColorDodge = 100;
static const int BlendColorBurn = 110;
static const int BlendHardLight = 120;
static const int BlendSoftLight = 130;

/**
 * \brief Blend Color
 * \param a sourceColor
 * \param b inputColor
 * \param mode blend mode
 * \return blended color
 */
half4 Blend(half4 a, half4 b, int mode)
{
    half4 result = a;
    switch (mode)
    {
        case BlendAlphaBlend:
            result = lerp(a, b, b.a);
            break;
        case BlendAdd:
            result = a + b;
            break;
        case BlendAddLighter:
            result = lerp(a, a + b, pow(CalcLuminance(a.rgb), 0.5));
            break;
        case BlendSubtract:
            result = a - b;
            break;
        case BlendMultiply:
            result = a * b;
            break;
        case BlendScreen:
            result = 1.0 - (1.0 - a) * (1.0 - b);
            break;
        case BlendOverlay:
            result = a < 0.5 ? 2.0 * a * b : 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
            break;
        case BlendDarken:
            result = min(a, b);
            break;
        case BlendLighten:
            result = max(a, b);
            break;
        case BlendColorDodge:
            result = b == 1.0 ? b : min(1.0, a / (1.0 - b));
            break;
        case BlendColorBurn:
            result = b == 0.0 ? b : max(0.0, 1.0 - (1.0 - a) / b);
            break;
        case BlendHardLight:
            result = a < 0.5 ? 2.0 * a * b : 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
            break;
        case BlendSoftLight:
            result = b < 0.5 ? 2.0 * a * b + a * a * (1.0 - 2.0 * b) : sqrt(a) * (2.0 * b - 1.0) + 2.0 * a * (1.0 - b);
            break;
        case BlendDifference:
            result = abs(a - b);
            break;
        default:
            break;
    }

    return result;
}

/**
 * \brief Blend Color
 * \param a sourceColor
 * \param b inputColor
 * \param mode blend mode
 * \return blended color
 */
half3 Blend(half3 a, half3 b, int mode)
{
    half3 result = a;
    switch (mode)
    {
        case BlendAlphaBlend:
            break;
        case BlendAdd:
            result = a + b;
            break;
        case BlendSubtract:
            result = a - b;
            break;
        case BlendMultiply:
            result = a * b;
            break;
        case BlendScreen:
            result = 1.0 - (1.0 - a) * (1.0 - b);
            break;
        case BlendOverlay:
            result = a < 0.5 ? 2.0 * a * b : 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
            break;
        case BlendDarken:
            result = min(a, b);
            break;
        case BlendLighten:
            result = max(a, b);
            break;
        case BlendColorDodge:
            result = b == 1.0 ? b : min(1.0, a / (1.0 - b));
            break;
        case BlendColorBurn:
            result = b == 0.0 ? b : max(0.0, 1.0 - (1.0 - a) / b);
            break;
        case BlendHardLight:
            result = a < 0.5 ? 2.0 * a * b : 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
            break;
        case BlendSoftLight:
            result = b < 0.5 ? 2.0 * a * b + a * a * (1.0 - 2.0 * b) : sqrt(a) * (2.0 * b - 1.0) + 2.0 * a * (1.0 - b);
            break;
        case BlendDifference:
            result = abs(a - b);
            break;
        default:
            break;
    }

    return result;
}
#endif
