#ifndef LEVEL_INCLUDED
#define LEVEL_INCLUDED

#ifndef UNITY_COLOR_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#endif

float _HueShift;
float _Saturation;
float _Value;

float _InputBlack;
float _InputWhite;
float _Gamma;
float _Contrast;
float _Brightness;
float _InvertLuma;

// Apply HSV shift to color
half3 ApplyHsvShift(half3 rgb)
{
    float3 hsv = RgbToHsv(rgb);
    hsv.x = frac(hsv.x + _HueShift);
    hsv.y = saturate(hsv.y * _Saturation);
    hsv.z = saturate(hsv.z * _Value);
    return HsvToRgb(hsv);
}

half3 ApplyHsvShift(half3 rgb, half3 hsvAdjust)
{
    float3 hsv = RgbToHsv(rgb);
    hsv.x = frac(hsv.x + hsvAdjust.x);
    hsv.y = saturate(hsv.y * hsvAdjust.y);
    hsv.z = saturate(hsv.z * hsvAdjust.z);
    return HsvToRgb(hsv);
}

// Remap raw luminance so the image's usable tonal range fills 0-1.
// Stretches [InputBlack, InputWhite] to full range, then applies
// gamma, contrast (pivoted around mid-grey) and a brightness offset.
float AdjustLuminance(float luma)
{
    // Levels: stretch input range to 0-1 (guard against zero span)
    float span = max(_InputWhite - _InputBlack, 1e-4);
    float t = saturate((luma - _InputBlack) / span);

    // Gamma correction
    t = pow(t, 1.0 / max(_Gamma, 1e-4));

    // Contrast around mid-grey + brightness offset
    t = saturate((t - 0.5) * _Contrast + 0.5 + _Brightness);

    // Optional inversion (dark subject on light bg vs. reverse)
    t = lerp(t, 1.0 - t, _InvertLuma);

    return t;
}
#endif // LEVEL_INCLUDED
