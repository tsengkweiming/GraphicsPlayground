#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDE_COLOR
#define POSTEFFECT_GRAPH_HLSL_INCLUDE_COLOR

#include "Packages/com.team-lab.posteffect-graph/Runtime/Shaders/Constant.hlsl"

static const float3x3 RgbToYiq = { 0.299, 0.587, 0.114, 0.595716, -0.274453, -0.321263, 0.211456, -0.522591, 0.311135 };
static const float3x3 YiqToRgb = { 1.0, 0.9563, 0.6210, 1.0, -0.2721, -0.6474, 1.0, -1.1070, 1.7046 };
static const float3x3 LinToLms = { 3.90405e-1, 5.49941e-1, 8.92632e-3, 7.08416e-2, 9.63172e-1, 1.35775e-3, 2.31082e-2, 1.28021e-1, 9.36245e-1 };
static const float3x3 LmsToLin = { 2.85847e+0, -1.62879e+0, -2.48910e-2, -2.10182e-1, 1.15820e+0, 3.24281e-4, -4.18120e-2, -1.18169e-1, 1.06867e+0 };

inline half3 AdjustContrast(half3 color, float contrast)
{
    return color < 0.5 ? pow(color * 2, contrast) * 0.5 : (1.0 - pow(2.0 * (1.0 - color), contrast) * 0.5);
}

inline float AdjustContrast(float val, float contrast)
{
    return val < 0.5 ? pow(val * 2, contrast) * 0.5 : (1.0 - pow(2.0 * (1.0 - val), contrast) * 0.5);
}

float3 ConvertRgbToHsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    const float d = q.x - min(q.w, q.y);
    const float e = 1.0e-5;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 ConvertHsvToRgb(float3 c)
{
    const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    const float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/**
 * \brief Linear->Gamma変換
 * https://en.wikipedia.org/wiki/SRGB
 */
float3 ConvertLinearToGamma(float3 c)
{
    const float3 linearRGB = saturate(c);
    return saturate(linearRGB <= 0.0031308 ? linearRGB * 12.92 : 1.055 * pow(linearRGB, 0.416666667) - 0.055);
}

/**
 * \brief Gamma->Linear変換
 * https://en.wikipedia.org/wiki/SRGB
 */
float3 ConvertGammaToLinear(float3 c)
{
    const float3 gammaRGB = saturate(c);
    return saturate(gammaRGB <= 0.04045 ? gammaRGB / 12.92 : pow((gammaRGB + 0.055) / 1.055, 2.4));
}

/**
 * \brief HSVをずらす
 */
float3 HsvShift(float3 color, float3 hsvShift)
{
    float3 hsv = ConvertRgbToHsv(color);
    hsv.x += hsvShift.x;
    hsv.x %= 1.0;
    hsv.y = hsv.y * hsvShift.y;
    hsv.z = hsv.z * hsvShift.z;
    return ConvertHsvToRgb(hsv);
}

/**
 * \brief YIQ色空間で色相をずらす
 * https://mofu-dev.com/blog/introducing-yiq/
 */
float3 HueShiftYiq(float3 color, float hueShift)
{
    float3 yColor = mul(RgbToYiq, saturate(color - 0.0000001));

    const float originalHue = atan2(yColor.b, yColor.g);
    const float finalHue = originalHue - hueShift * 2.0 * PI;

    const float chroma = sqrt(yColor.b * yColor.b + yColor.g * yColor.g);
    const float3 yFinalColor = float3(yColor.r, chroma * cos(finalHue), chroma * sin(finalHue));

    return mul(YiqToRgb, yFinalColor);
}

/**
 * \brief ホワイトバランスを調整する
 * \param c 入力色
 * \param balance ホワイトバランス (ColorUtility.ComputeColorBalance()でC#側で計算した値)
 * \return ホワイトバランス調整後の色
 */
float3 WhiteBalance(float3 c, float3 balance)
{
    float3 lms = mul(LinToLms, c);
    lms *= balance;
    return mul(LmsToLin, lms);
}

/**
 * \brief 色の明るさを計算する
 */
inline float CalcLuminance(float3 color)
{
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
} 

#endif