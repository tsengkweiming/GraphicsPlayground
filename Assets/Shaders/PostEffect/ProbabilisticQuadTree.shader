Shader "Hidden/URP/ProbabilisticQuadTree"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Source Texture", 2D) = "white" {}
        _Threshold ("Variance Threshold", Range(0.0001, 0.01)) = 0.0025
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

            #define MIN_DIVISIONS 4.0
            #define MAX_ITERATIONS 6
            #define SAMPLES_PER_ITERATION 30

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float _Threshold;
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

            // A deterministic 2D hash. Keeping the quad center as the seed means
            // every pixel in a quad uses the same sample locations.
            float2 Hash22(float2 p)
            {
                float n = sin(dot(p, float2(41.0, 289.0)));
                return frac(float2(262144.0, 32768.0) * n);
            }

            // Estimate the average color and RGB variance of one candidate quad.
            float4 QuadColorVariation(float2 center, float size)
            {
                float3 samplesBuffer[SAMPLES_PER_ITERATION];
                float3 average = 0.0;

                [unroll]
                for (int i = 0; i < SAMPLES_PER_ITERATION; ++i)
                {
                    float sampleIndex = (float)i;
                    float2 randomPoint = Hash22(center + float2(sampleIndex, 0.0)) - 0.5;
                    float3 sampleColor = SAMPLE_TEXTURE2D(
                        _MainTex,
                        sampler_MainTex,
                        center + randomPoint * size).rgb;

                    average += sampleColor;
                    samplesBuffer[i] = sampleColor;
                }

                average /= (float)SAMPLES_PER_ITERATION;

                float3 variance = 0.0;

                [unroll]
                for (int i = 0; i < SAMPLES_PER_ITERATION; ++i)
                {
                    variance += samplesBuffer[i] * samplesBuffer[i];
                }

                variance /= (float)SAMPLES_PER_ITERATION;
                variance -= average * average;

                return float4(average, (variance.x + variance.y + variance.z) / 3.0);
            }

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
                    quadInfo = QuadColorVariation(quadCenter, quadSize);

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

                color -= lineMask * _LineStrength;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
