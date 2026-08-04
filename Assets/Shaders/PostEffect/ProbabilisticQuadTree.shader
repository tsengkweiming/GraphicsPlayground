Shader "Hidden/URP/ProbabilisticQuadTree"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Source Texture", 2D) = "white" {}
        _Threshold ("Variance Threshold", Range(0.0001, 0.01)) = 0.0025
        _LineColor ("Grid Line Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _LineWidth ("Grid Line Width (Pixels)", Range(0.1, 4.0)) = 1.0
        _LineStrength ("Grid Line Strength", Range(0.0, 1.0)) = 1.0
        _Resolution ("Resolution (Grid Columns)", Range(0, 350)) = 60
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        ZWrite Off
        Cull Off

        Pass
        {
            Name "ProbabilisticQuadTree"

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/Common/QuadTree.hlsl"

            #define MIN_DIVISIONS 4.0
            #define MAX_ITERATIONS 6
            #define SAMPLES_PER_ITERATION 30

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float _Threshold;
                float4 _LineColor;
                float _LineWidth;
                float _LineStrength;
                float _Resolution;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float2 analysisUv = uv;

                float2 asp = _ScaledScreenParams.x /
                             max(_ScaledScreenParams.y, 1.0);

                float enabled = step(0.5, _Resolution);
                float cols = max(_Resolution, 1.0);
                float rows = max(floor(cols / max(asp, 0.0001)), 1.0);

                float2 grid = float2(cols, rows);
                float2 cellCenterUv = (floor(uv * grid) + 0.5) / grid;

                analysisUv = lerp(uv, cellCenterUv, enabled);
                
                float divisions = MIN_DIVISIONS;
                float2 quadCenter = (floor(analysisUv * divisions) + 0.5) / divisions;
                float quadSize = 1.0 / divisions;
                float4 quadInfo = 0.0;

                [loop]
                for (int iteration = 0; iteration < MAX_ITERATIONS; ++iteration)
                {
                    quadInfo = QuadColorVariation(_MainTex, sampler_MainTex, quadCenter, quadSize);

                    if (quadInfo.w < _Threshold)
                        break;

                    divisions *= 2.0;
                    quadCenter = (floor(analysisUv * divisions) + 0.5) / divisions;
                    quadSize *= 0.5;
                }

                float3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, analysisUv).rgb;

                // Draw the boundary of the selected adaptive quad. _ScaledScreenParams
                // is the URP equivalent of Shadertoy's iResolution for this pass.
                float2 normalizedQuadUV = frac(uv * divisions);
                float2 pixelWidth = _LineWidth / max(_ScaledScreenParams.xy, 1.0);
                float2 distanceToCenter = abs(normalizedQuadUV - 0.5);
                float lineMask =
                    step(0.5 - distanceToCenter.x, pixelWidth.x * divisions) +
                    step(0.5 - distanceToCenter.y, pixelWidth.y * divisions);

                float lineBlend = saturate(lineMask * _LineStrength);
                color = lerp(color, _LineColor.rgb, lineBlend);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
