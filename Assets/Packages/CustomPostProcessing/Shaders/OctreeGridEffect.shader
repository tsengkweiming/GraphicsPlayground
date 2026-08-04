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
            #include "Common/Noise/SimplexNoise3D.cginc"

            #pragma vertex Vert
            #pragma fragment frag
            
            float _T;
            float _Size;
            float _Z;
            float _Z2;
            float _BeatsPerMinute;
            float _BorderRate;
            float4 _BorderColor;
            // Pseudo-random generator based on a seed
            float random1to1(float seed) {
                return frac(sin(seed * 12.9898) * 43758.5453);
            }
            
            float gridOutline(float3 p, float3 cellSize, float lineWidth)
            {
                float3 localPos = abs(fmod(p + 0.5 * cellSize, cellSize) - 0.5 * cellSize);
                float3 halfSize = 0.5 * cellSize;
                float3 edgeDist = halfSize - localPos;

                // Thin line around each axis-aligned boundary
                float border = step(edgeDist.x, lineWidth) + step(edgeDist.y, lineWidth) + step(edgeDist.z, lineWidth);
                return saturate(border); // 0 or 1
            }
            
            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;
                float2 asp = _ScaledScreenParams.x / _ScaledScreenParams.y;

                float bpm = 4 * 60.0 / _BeatsPerMinute;
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

                float z = _Z;//6.25, 4.25 4.75 // -0.04~-0.3

                float3 col = float3( 0.0, 0.0, 0.0 );

                // fill the cell at the pixel
                SubdivResult subdiv = subdivision( float3( p, z ) );
                //col = subdiv.hash;
                // float2 newUv = clamp((subdiv.hash.xy + 0.5) * uv * _Size, 0.,1.);
                // if (newUv.x > 0.4 && newUv.x < 0.5 && newUv.y > 0.4 && newUv.y < 0.5)
                //     col = float3(1,0,0);

                float3 pos = float3(p, lerp(0,_Z2, pulse));
                float3 newSize = _Size;
                // newSize.z = lerp(1, 0, pulse);
                // float shouldDraw = step(_BorderRate, subdiv.hash.x); // 1 if hash.x < rate, else 0
                // shouldDraw = step(0.15, subdiv.hash.x) * step(subdiv.hash.y, 0.3);
                float shouldDraw = step(subdiv.hash.z, _BorderRate);
                float border = gridOutline(pos + float3(1.75,1,0), subdiv.size * newSize, 0.001) * shouldDraw; // 0.01 is line width
                // border = lerp(0, border, pulse);
                // return float4(border.xxx,1);
                // return float4(1 - border.xxx, 1); // white lines, black background

                // return float4(col,1);
                //return float4(subdiv.hash.xy,0,1);
                // return float4(step(0.5, subdiv.hash.x) * step(0.5, subdiv.hash.y),0,0,1);
                return float4(_BorderColor * border.xxx,0) + GetSource(lerp(uv, clamp((subdiv.hash.xy + 0.5) * coord * _Size, 0.,1.), _T));
            }
            ENDHLSL
        }
    }
}
