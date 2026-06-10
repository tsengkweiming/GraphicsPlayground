#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDED_SHARPEN
#define POSTEFFECT_GRAPH_HLSL_INCLUDED_SHARPEN

#include "Packages/com.team-lab.posteffect-graph/Runtime/Shaders/Color.hlsl"

float _Sharpness;
float _Radius;
float _ContrastMaskRange;

/**
 * Applies a high-quality sharpening effect.
 * - 8-direction sampling for smooth edges.
 * - Luma-based processing to prevent color shifting.
 * - Contrast mask to suppress noise in flat areas.
 */
float4 SharpenColor8(sampler2D tex, float2 uv, float2 texelSize)
{
    float2 offsetH = float2(texelSize.x, 0) * _Radius; // Horizontal
    float2 offsetV = float2(0, texelSize.y) * _Radius; // Vertical

    float4 centerColor = tex2D(tex, uv);
    float lumaCenter = CalcLuminance(centerColor);
    float lumaT  = CalcLuminance(tex2D(tex, uv + offsetV).rgb);       // Top
    float lumaB  = CalcLuminance(tex2D(tex, uv - offsetV).rgb);       // Bottom
    float lumaR  = CalcLuminance(tex2D(tex, uv + offsetH).rgb);       // Right
    float lumaL  = CalcLuminance(tex2D(tex, uv - offsetH).rgb);       // Left
    float lumaTL = CalcLuminance(tex2D(tex, uv + offsetV - offsetH).rgb); // Top-Left
    float lumaTR = CalcLuminance(tex2D(tex, uv + offsetV + offsetH).rgb); // Top-Right
    float lumaBL = CalcLuminance(tex2D(tex, uv - offsetV - offsetH).rgb); // Bottom-Left
    float lumaBR = CalcLuminance(tex2D(tex, uv - offsetV + offsetH).rgb); // Bottom-Right

    // Contrast Masking
    float minLuma = min(lumaCenter, min(min(lumaT, lumaB), min(lumaR, lumaL)));
    minLuma = min(minLuma, min(min(lumaTL, lumaTR), min(lumaBL, lumaBR)));
    float maxLuma = max(lumaCenter, max(max(lumaT, lumaB), max(lumaR, lumaL)));
    maxLuma = max(maxLuma, max(max(lumaTL, lumaTR), max(lumaBL, lumaBR)));

    // Making a contrast mask based on the luminance difference
    float contrastMask = saturate((maxLuma - minLuma) * _ContrastMaskRange);

    float edge = lumaCenter * 8.0 - (lumaT + lumaB + lumaR + lumaL + lumaTL + lumaTR + lumaBL + lumaBR);
    return float4(saturate(centerColor.rgb + edge * _Sharpness * contrastMask), centerColor.a);
}

/**
 * Applies a high-quality sharpening effect.
 * - 4-direction sampling for smooth edges.
 * - Luma-based processing to prevent color shifting.
 * - Contrast mask to suppress noise in flat areas.
 */
float4 SharpenColor4(sampler2D tex, float2 uv, float2 texelSize)
{
    float2 offsetH = float2(texelSize.x, 0) * _Radius; // Horizontal
    float2 offsetV = float2(0, texelSize.y) * _Radius; // Vertical

    float4 centerColor = tex2D(tex, uv);
    float lumaCenter = CalcLuminance(centerColor);
    float lumaT  = CalcLuminance(tex2D(tex, uv + offsetV).rgb);       // Top
    float lumaB  = CalcLuminance(tex2D(tex, uv - offsetV).rgb);       // Bottom
    float lumaR  = CalcLuminance(tex2D(tex, uv + offsetH).rgb);       // Right
    float lumaL  = CalcLuminance(tex2D(tex, uv - offsetH).rgb);       // Left

    // Contrast Masking
    float minLuma = min(lumaCenter, min(lumaT, min(lumaB, min(lumaR, lumaL))));
    float maxLuma = max(lumaCenter, max(lumaT, max(lumaB, max(lumaR, lumaL))));

    // Making a contrast mask based on the luminance difference
    float contrastMask = saturate((maxLuma - minLuma) * _ContrastMaskRange);

    float edge = lumaCenter * 4.0 - (lumaT + lumaB + lumaR + lumaL);
    return float4(saturate(centerColor.rgb + edge * _Sharpness * contrastMask), centerColor.a);
}

#endif