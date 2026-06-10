#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDED_COLOR_CORRECT
#define POSTEFFECT_GRAPH_HLSL_INCLUDED_COLOR_CORRECT

#include "Packages/com.team-lab.posteffect-graph/Runtime/Shaders/Color.hlsl"

int _HueShiftType;
float _HueShift;
float _SaturationMultiplier;
float3 _WhiteBalance;

/**
 * Adjusts the color of the color.
 * @param color The color to adjust.
 */
void CorrectColor(inout float4 color)
{
     // Apply Hue Shift & Saturation
     color = _HueShiftType == 0
             ? half4(saturate(HsvShift(color.rgb, float3(_HueShift, _SaturationMultiplier, 1.0))), color.a)
             : half4(saturate(HsvShift(HueShiftYiq(color.rgb, _HueShift), float3(0.0, _SaturationMultiplier, 1.0))), color.a);

     // Apply White Balance
     color = half4(saturate(WhiteBalance(color.rgb, _WhiteBalance)), color.a);
}

#endif