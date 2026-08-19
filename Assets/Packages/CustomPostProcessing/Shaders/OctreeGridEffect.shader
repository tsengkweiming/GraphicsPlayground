Shader "Hidden/CustomPostProcess/OctreeGridEffect"
{
    Properties
	{ }
    SubShader
    {
        Tags { "RenderType"="Opaque"
               "RenderPipeline"="UniversalPipeline"
        }
        LOD 200
        ZWrite Off
        Cull off
        Pass
        {
            Name "OctreeGridEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            #include "Common/OctreeGrid.hlsl"

            #pragma vertex Vert
            #pragma fragment frag

            // Runtime controls supplied by OctreeGridEffect.cs.
            float _T;
            float _Size;
            float _Z;
            float _Z2;
            float _BorderRate;
            float _SubdivisionStopThreshold;
            int _CellCount;
            float3 _CellSize;
            float4 _BorderColor;

            // Pseudo-random generator based on a seed
            float random1to1(float seed)
            {
                return frac(sin(seed * 12.9898) * 43758.5453);
            }
            
            float gridOutline(float3 p, float3 cellSize, float lineWidth)
            {
                float3 safeCellSize = max(abs(cellSize), GRID_EPSILON);
                float3 localPos = abs(fmod(p + 0.5 * safeCellSize, safeCellSize)
                                    - 0.5 * safeCellSize);
                float3 halfSize = 0.5 * safeCellSize;
                float3 edgeDist = halfSize - localPos;

                // Thin line around each axis-aligned boundary
                float border = step(edgeDist.x, lineWidth) + step(edgeDist.y, lineWidth) + step(edgeDist.z, lineWidth);
                return saturate(border); // 0 or 1
            }
            
            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;
                float asp = _ScaledScreenParams.x / _ScaledScreenParams.y;
                const float beatsPerMinute = 120.0;
                float bpm = 4.0 * 60.0 / beatsPerMinute; // / _BeatsPerMinute;
                float cycle = 1e-6 + bpm;
                float timeMod = fmod(_Time.y, cycle);
                float seed = floor(_Time.y / cycle);
                float speed = 0.3; // Slide speed
                float band = lerp(0.2, 1.2, random1to1(seed));
                float offset = lerp(0, 1, random1to1(seed+12));
                float pulseWidth = 1.05; // short duration (e.g., 5% of a cycle)
                float pulse = step(timeMod, pulseWidth * cycle) * saturate(timeMod / pulseWidth);

                float2 coord = lerp(uv.xy, uv.yx, fmod(floor(random1to1(seed+123)*2), 2));
                float postion = coord.y + offset;
                coord.x += timeMod * speed * step(band/2, fmod(postion, band)) * lerp(-1,1, fmod(floor(postion / band), 2));
                coord.x = frac(coord.x); // wrap-around
            
                // uv.y += _Time.y * speed * step(uv.y, 0.5);
                // uv.y = frac(uv.y); // Optional wrap-around
                
                float2 p = coord * 2.0 - 1.0;
                p.x *= asp;
                
                // fill the cell at the pixel
                SubdivResult subdiv = subdivision(
                    float3(p, _Z),
                    _CellSize,
                    _CellCount,
                    _SubdivisionStopThreshold);

                float3 pos = float3(p, lerp(0,_Z2, pulse));
                float shouldDraw = step(subdiv.hash.z, _BorderRate);
                float border = gridOutline(
                    pos + float3(1.75, 1.0, 0.0),
                    subdiv.size * _Size,
                    0.001) * shouldDraw;

                float2 sampleUv = clamp(
                    (subdiv.hash.xy + 0.5) * coord * _Size,
                    0.0,
                    1.0);
                half4 color = GetSource(lerp(uv, sampleUv, _T));
                color.rgb += (half3)_BorderColor.rgb * border;
                return color;
            }
            ENDHLSL
        }
    }
}
