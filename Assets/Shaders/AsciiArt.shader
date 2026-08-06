Shader "Hidden/ASCII Art"
{
    Properties
    {
        [MainTexture] _MainTex ("Reference Image", 2D) = "white" {}

        // SVG Pattern Textures for different brightness levels
        _Pattern0 ("Pattern 0 (Darkest)", 2D) = "white" {}
        _Pattern1 ("Pattern 1", 2D) = "white" {}
        _Pattern2 ("Pattern 2", 2D) = "white" {}
        _Pattern3 ("Pattern 3", 2D) = "white" {}
        _Pattern4 ("Pattern 4 (Brightest)", 2D) = "white" {}

        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _Resolution ("Resolution (Grid Columns)", Range(10, 350)) = 60
        _PosterizeLevels ("Posterize Levels", Range(-2, 50)) = 5
        _QuadTreeThreshold ("Quad Tree Variance Threshold", Range(0.0001, 0.01)) = 0.0025

        // --- Tonal range controls (stretch image luminance into full pattern range) ---
        _InputBlack ("Input Black Point", Range(0, 1)) = 0
        _InputWhite ("Input White Point", Range(0, 1)) = 1
        _Gamma ("Gamma", Range(0.1, 5)) = 1
        _Contrast ("Contrast", Range(0, 4)) = 1
        _Brightness ("Brightness", Range(-1, 1)) = 0
        [Toggle] _InvertLuma ("Invert Luminance", Float) = 0

        // --- HSV Color shift ---
        _HueShift ("Hue Shift", Range(0, 1)) = 0
        _Saturation ("Saturation", Range(0, 2)) = 1
        _Value ("Value (Brightness)", Range(0, 2)) = 1
        
        _Threshold ("Variance Threshold", Range(0.0001, 0.01)) = 0.0025
        _LineColor ("Grid Line Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _LineWidth ("Grid Line Width (Pixels)", Range(0.1, 4.0)) = 1.0
        _LineStrength ("Grid Line Strength", Range(0.0, 1.0)) = 1.0
        
        _PhaseSpeed ("Mono Phase Speed", Float) = 0.1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Unlit"
        }

        LOD 100
        Cull Off
        ZWrite On

        Pass
        {
            Name "FlowerASCIIPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_instancing

            // Adaptive reference-image sampling. A quad is subdivided when the
            // estimated RGB variance inside it is above _QuadTreeThreshold.
            #define ASCII_QUADTREE_MIN_DIVISIONS 4.0
            #define ASCII_QUADTREE_MAX_ITERATIONS 6
            #define ASCII_QUADTREE_SAMPLES_PER_ITERATION 30
            #define ASCII_QUADTREE_F_SAMPLES_PER_ITERATION 30.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/Common/QuadTree.hlsl"
            #include "Assets/Shaders/Common/MonoPhase.hlsl"
            #include "Assets/Shaders/Common/Pattern.hlsl"
            #include "Assets/Shaders/Common/Level.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_Pattern0);
            SAMPLER(sampler_Pattern0);
            TEXTURE2D(_Pattern1);
            SAMPLER(sampler_Pattern1);
            TEXTURE2D(_Pattern2);
            SAMPLER(sampler_Pattern2);
            TEXTURE2D(_Pattern3);
            SAMPLER(sampler_Pattern3);
            TEXTURE2D(_Pattern4);
            SAMPLER(sampler_Pattern4);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Pattern0_ST;
                float4 _Pattern1_ST;
                float4 _Pattern2_ST;
                float4 _Pattern3_ST;
                float4 _Pattern4_ST;
                half4 _BackgroundColor;
                float _Resolution;
                float _PosterizeLevels;
                float _QuadTreeThreshold;
                float _Threshold;
                float4 _LineColor;
                float _LineWidth;
                float _LineStrength;
            CBUFFER_END

            Varyings Vertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
              //   #if UNITY_UV_STARTS_AT_TOP
		            // input.uv.y = 1.0 - input.uv.y;
              //   #endif
                output.uv = input.uv;
                return output;
            }

            // Posterize function: reduce brightness levels
            float Posterize(float brightness, float levels)
            {
                float step = 1.0 / max(levels, 1.0);
                return floor(brightness / step) * step;
            }

            float3 SampleReference(float2 uv)
            {
                float2 sampleUv = uv * _MainTex_ST.xy + _MainTex_ST.zw;
                return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(sampleUv)).rgb;
            }

            // Map brightness (0-1) to Pattern index (0-4)
            int GetIndex(float brightness, int numPatterns)
            {
                // Invert: darker -> lower index (more detail)
                float inverted = 1.0 - brightness;
                int index = int(floor(inverted * numPatterns));
                return clamp(index, 0, numPatterns - 1);
            }

            // Sample the appropriate pattern based on brightness
            half3 SamplePattern(float2 uv, int patternIndex)
            {
                half3 color = half3(1, 1, 1);

                if (patternIndex == 0)
                    color = SAMPLE_TEXTURE2D(_Pattern0, sampler_Pattern0, uv).rgb;
                else if (patternIndex == 1)
                    color = SAMPLE_TEXTURE2D(_Pattern1, sampler_Pattern1, uv).rgb;
                else if (patternIndex == 2)
                    color = SAMPLE_TEXTURE2D(_Pattern2, sampler_Pattern2, uv).rgb;
                else if (patternIndex == 3)
                    color = SAMPLE_TEXTURE2D(_Pattern3, sampler_Pattern3, uv).rgb;
                else
                {
                    // color = SAMPLE_TEXTURE2D(_Pattern4, sampler_Pattern4, uv).rgb;
                    // pattern = pattern_ring(uv, 19, _Time.y);
                    // pattern = pattern_stripe(uv, 19, _Time.y*5);
                    // pattern = pattern_grid(uv, 9);
                    // pattern = pattern_rect(uv, fixed2(0.4,0.1));
                    float pattern = pattern_circles(uv, 3, 0.35, _Time.y);
                    color = lerp(float3(0,0,0), 1, pattern);
                }
                    
                return color;
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

            half4 Fragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.uv;
                float2 asp = _ScaledScreenParams.x /
                             max(_ScaledScreenParams.y, 1.0);
                
                float cols = _Resolution;
                float rows = floor(cols / asp);

                // Current grid cell
                float2 cellId = floor(uv * float2(cols, rows));
                float2 cellUv = frac(uv * float2(cols, rows));

                // Replace the fixed cell-center lookup with an adaptive
                // quadtree lookup. The ASCII pattern itself still uses the
                // original regular grid through cellUv.
                float2 cellCenterUv = (cellId + 0.5) / float2(cols, rows);

                float2 analysisUv = cellCenterUv;
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
                // Draw the boundary of the selected adaptive quad. _ScaledScreenParams
                // is the URP equivalent of Shadertoy's iResolution for this pass.
                float2 normalizedQuadUV = frac(uv * divisions);
                float2 pixelWidth = _LineWidth / max(_ScaledScreenParams.xy, 1.0);
                float2 distanceToCenter = abs(normalizedQuadUV - 0.5);
                float lineMask =
                    step(0.5 - distanceToCenter.x, pixelWidth.x * divisions) +
                    step(0.5 - distanceToCenter.y, pixelWidth.y * divisions);

                float lineBlend = saturate(lineMask * _LineStrength);
                
                // float quadSize;
                // FindQuadTreeSample(uv, cellCenterUv, quadSize);
                half3 refColor = (half3)SampleReference(analysisUv);

                // Calculate brightness (0-1)
                float brightness = dot(refColor, float3(0.299, 0.587, 0.114));

                // Remap tonal range so more of the pattern set is used
                brightness = AdjustLuminance(brightness);

                // Posterize brightness
                float posterized = Posterize(brightness, _PosterizeLevels);

                // Map to Pattern index
                int imgIndex = GetIndex(posterized, 5);

                // Sample the appropriate Pattern
                half3 result = SamplePattern(cellUv, imgIndex);

                // Apply HSV shift
                result = ApplyHsvShift(result);

                half3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(uv)).rgb;
                float index = mono_phase(uv, _Time.y);
                return float4(lerp(color, result, index),1);
                result = uv.x > 0.5 ? result : color;
                result = lerp(result, _LineColor.rgb, lineBlend);
                return half4(result, 1.0);
                // return half4(uv.x > 0.25 ? result : color, _BackgroundColor.a);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
