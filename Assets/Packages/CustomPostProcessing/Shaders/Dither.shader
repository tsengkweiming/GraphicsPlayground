Shader "Hidden/CustomPostProcess/Dither"
{
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
            Name "MirrorEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            
            #pragma vertex Vert
            #pragma fragment frag
            
            float _Factor;
            float _PixelFactor;
            float _ColorFactor;
            float4 _Palette[4];
            float2 _MaskCenter;    // UV position, e.g. (0.5, 0.5)
            float _MaskRadius;     // radius in UV space, e.g. 0.3
            float _Scale;
            float _DitherStrength;
            int _MaskCount;
            float _MonoFactor;

            const float4x4 ditherTable = float4x4(
                -4.0, 0.0, -3.0, 1.0,
                2.0, -2.0, 3.0, -1.0,
                -3.0, 1.0, -4.0, 0.0,
                3.0, -1.0, 2.0, -2.0
            );

            void CalcScale(in int index, out float2 center, out float radius)
            {
                // Time-based alpha for smooth transition over 3 seconds
                // float t = frac(_Time.y / 3.0);
                float cycle = 4.0;              // Total cycle duration: 3s interpolate + 1s hold
                float interpDuration = 1.0;     // Duration of interpolation
                float timeMod = fmod(_Time.y, cycle);
                float t = saturate(timeMod / interpDuration);  // Will stay at 1.0 for 1 second
                                
                // Store three center-from and center-to pairs (can also be uniforms from CPU if desired)
                float2 maskFrom[3] = {
                    float2(0.3, 0.3),
                    float2(0.7, 0.3),
                    float2(0.5, 0.7)
                };

                float2 maskTo[3] = {
                    float2(0.5, 0.2),
                    float2(0.25, 0.75),
                    float2(0.75, 0.75)
                };
                
                center = lerp(maskFrom[index], maskTo[index], t);
                float maskRadius[3] = { 0.2, 0.15, 0.18 };
                radius = maskRadius[index];
            }

            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;

                float asp = _ScaledScreenParams.x / _ScaledScreenParams.y;
                float2 size = _PixelFactor * _ScaledScreenParams.xy/_ScaledScreenParams.x;
                float2 coor = floor( uv * size) ;
                uv = coor / size;

                _MaskCenter = float2(0.5,0.5);
                _MaskRadius = 0.2;
                _Scale = 1 / 4.0;
                
                // Calculate distance to mask center
                for (int i = 0; i < _MaskCount; i++)
                {
                    float2 center;
                    float radius;
                    CalcScale(i, center, radius);    
                    float dist = distance(uv, center);
                    if (dist < radius)
                    {
                        size *= _Scale;
                        coor = floor( uv * size ) ;
                        uv = coor / size;
                    }
                }

                // Get source color
                float3 col = GetSource(uv).rgb;

                // Dither
                float3 effect = col.rgb + ditherTable[int( coor.x ) % 4][int( coor.y ) % 4] * _DitherStrength; // last number is dithering strength

                // Convert to brightness
                float brightness = dot(effect, float3(0.299, 0.587, 0.114)) * 1.0;
                brightness = pow(brightness,0.5);
                // brightness = normalize(brightness);

                // Map brightness to color index
                int paletteIndex = clamp((int)(brightness * 4.0), 0, 3);
                effect = lerp(effect, _Palette[paletteIndex], _MonoFactor);
                
                // Reduce colors    
                effect = floor(effect * _ColorFactor) / _ColorFactor;
                
                return float4(lerp(col, effect, _Factor),1);
            }
            ENDHLSL
        }
    }
}
