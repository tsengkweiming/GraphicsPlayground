#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDED_LEVEL_ADJUST
#define POSTEFFECT_GRAPH_HLSL_INCLUDED_LEVEL_ADJUST

#include "Packages/com.team-lab.posteffect-graph/Runtime/Shaders/Color.hlsl"

float _Exposure;
float _Contrast;
float _BlackLevel;
float _WhiteLevel;
float _Gamma;
float _Brightness;
bool _Clamp;
float _ClampSaturation;
float _ClampValue;

/**
 * Adjusts the contrast of the color.
 * @param color The color to adjust.
 */
void AdjustLevel(inout float4 color)
{
    // Adjust Post Exposure
    color.rgb = saturate(color.rgb * _Exposure);
                
    // Apply Contrast
    color.rgb = AdjustContrast(color.rgb, _Contrast);
                
    // Apply Black and White levels
    color.rgb = saturate((color.rgb - _BlackLevel) / (_WhiteLevel - _BlackLevel));

    // Apply Gamma
    color.rgb = saturate(pow(color.rgb, 1.0 / _Gamma));

    // Apply Brightness
    color.rgb = HsvShift(color.rgb, float3(0.0f, 1.0f, _Brightness));

    // Clamp
    if (_Clamp)
    {
        color.rgb = saturate(color.rgb);
        float3 hsv = ConvertRgbToHsv(color.rgb);
        hsv.y = min(hsv.y, _ClampSaturation);
        hsv.z = min(hsv.z, _ClampValue);
        color.rgb = ConvertHsvToRgb(hsv);
    }
}
#endif