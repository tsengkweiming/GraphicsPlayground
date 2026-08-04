#ifndef LEVEL_INCLUDED
#define LEVEL_INCLUDED

float _HueShift;
float _Saturation;
float _Value;

float _InputBlack;
float _InputWhite;
float _Gamma;
float _Contrast;
float _Brightness;
float _InvertLuma;

// RGB to HSV conversion
float3 RgbToHsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
float3 HsvToRgb(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Apply HSV shift to color
half3 ApplyHsvShift(half3 rgb)
{
    float3 hsv = RgbToHsv(rgb);
    hsv.x = frac(hsv.x + _HueShift);
    hsv.y = saturate(hsv.y * _Saturation);
    hsv.z = saturate(hsv.z * _Value);
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
