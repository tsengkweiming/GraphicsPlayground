Shader "Hidden/ASCII Art (Optimized)"
{
    Properties
    {
        [MainTexture] _ReferenceImage ("Reference Image", 2D) = "white" {}

        // SVG Pattern Textures for different brightness levels
        _SVGPattern0 ("SVG Pattern 0 (Darkest)", 2D) = "white" {}
        _SVGPattern1 ("SVG Pattern 1", 2D) = "white" {}
        _SVGPattern2 ("SVG Pattern 2", 2D) = "white" {}
        _SVGPattern3 ("SVG Pattern 3", 2D) = "white" {}
        _SVGPattern4 ("SVG Pattern 4 (Brightest)", 2D) = "white" {}

        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _Resolution ("Resolution (Grid Columns)", Range(10, 550)) = 59
        _PosterizeLevels ("Posterize Levels", Range(2, 8)) = 5
        [Toggle] _FlipY ("Flip Y Axis", Float) = 0
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
            Name "FlowerASCIIOptimized"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex FlowerASCIIVertex
            #pragma fragment FlowerASCIIFragment
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

            TEXTURE2D(_ReferenceImage);
            SAMPLER(sampler_ReferenceImage);

            TEXTURE2D(_SVGPattern0);
            SAMPLER(sampler_SVGPattern0);
            TEXTURE2D(_SVGPattern1);
            SAMPLER(sampler_SVGPattern1);
            TEXTURE2D(_SVGPattern2);
            SAMPLER(sampler_SVGPattern2);
            TEXTURE2D(_SVGPattern3);
            SAMPLER(sampler_SVGPattern3);
            TEXTURE2D(_SVGPattern4);
            SAMPLER(sampler_SVGPattern4);

            CBUFFER_START(UnityPerMaterial)
                float4 _ReferenceImage_ST;
                float4 _SVGPattern0_ST;
                float4 _SVGPattern1_ST;
                float4 _SVGPattern2_ST;
                float4 _SVGPattern3_ST;
                float4 _SVGPattern4_ST;
                half4 _BackgroundColor;
                float _Resolution;
                float _PosterizeLevels;
                float _FlipY;
            CBUFFER_END

            Varyings FlowerASCIIVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // Posterize: reduce brightness to discrete levels
            float Posterize(float brightness, float levels)
            {
                float step = 1.0 / levels;
                return floor(brightness / step) * step;
            }

            // Map posterized brightness to SVG index using smooth interpolation
            // Darker brightness (lower value) → lower index (more pattern detail)
            float GetSVGIndexNormalized(float brightness)
            {
                // Invert brightness: 0 (white) → 5, 1 (black) → 0
                float inverted = 1.0 - brightness;
                return saturate(inverted * 5.0);
            }

            // Blend between textures smoothly based on index
            half3 SampleSVGPatternBlended(float2 cellUv, float indexNormalized)
            {
                // Determine which two patterns to blend
                int lowerIndex = int(floor(indexNormalized));
                float blend = frac(indexNormalized);

                half3 color = half3(0, 0, 0);

                // Sample and blend - using lerp to avoid branching
                if (lowerIndex == 0)
                {
                    half3 col0 = SAMPLE_TEXTURE2D(_SVGPattern0, sampler_SVGPattern0, cellUv).rgb;
                    half3 col1 = SAMPLE_TEXTURE2D(_SVGPattern1, sampler_SVGPattern1, cellUv).rgb;
                    color = lerp(col0, col1, blend);
                }
                else if (lowerIndex == 1)
                {
                    half3 col1 = SAMPLE_TEXTURE2D(_SVGPattern1, sampler_SVGPattern1, cellUv).rgb;
                    half3 col2 = SAMPLE_TEXTURE2D(_SVGPattern2, sampler_SVGPattern2, cellUv).rgb;
                    color = lerp(col1, col2, blend);
                }
                else if (lowerIndex == 2)
                {
                    half3 col2 = SAMPLE_TEXTURE2D(_SVGPattern2, sampler_SVGPattern2, cellUv).rgb;
                    half3 col3 = SAMPLE_TEXTURE2D(_SVGPattern3, sampler_SVGPattern3, cellUv).rgb;
                    color = lerp(col2, col3, blend);
                }
                else if (lowerIndex == 3)
                {
                    half3 col3 = SAMPLE_TEXTURE2D(_SVGPattern3, sampler_SVGPattern3, cellUv).rgb;
                    half3 col4 = SAMPLE_TEXTURE2D(_SVGPattern4, sampler_SVGPattern4, cellUv).rgb;
                    color = lerp(col3, col4, blend);
                }
                else
                {
                    color = SAMPLE_TEXTURE2D(_SVGPattern4, sampler_SVGPattern4, cellUv).rgb;
                }

                return color;
            }

            half4 FlowerASCIIFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Setup canvas UV (p5.js uses top-left origin)
                float2 canvasUv = input.uv;
                canvasUv.y = lerp(canvasUv.y, 1.0 - canvasUv.y, step(0.5, _FlipY));

                // Grid dimensions
                float cols = _Resolution;
                // Calculate rows based on typical 16:9 aspect (customize as needed)
                float rows = floor(cols * 9.0 / 16.0);

                // Current cell in grid
                float2 gridCoord = canvasUv * float2(cols, rows);
                float2 cellId = floor(gridCoord);
                float2 cellUv = frac(gridCoord);

                // Sample reference image at cell center
                float2 cellCenterUv = (cellId + 0.5) / float2(cols, rows);
                float2 sampleUv = cellCenterUv;
                sampleUv.y = lerp(sampleUv.y, 1.0 - sampleUv.y, step(0.5, _FlipY));
                sampleUv = sampleUv * _ReferenceImage_ST.xy + _ReferenceImage_ST.zw;

                half3 refColor = SAMPLE_TEXTURE2D(_ReferenceImage, sampler_ReferenceImage, saturate(sampleUv)).rgb;

                // Calculate luminance (standard RGB to grayscale)
                float brightness = dot(refColor, float3(0.299, 0.587, 0.114));

                // Posterize
                float posterized = Posterize(brightness, _PosterizeLevels);

                // Map to SVG pattern range
                float svgIndex = GetSVGIndexNormalized(posterized);

                // Sample and blend SVG pattern
                half3 result = SampleSVGPatternBlended(cellUv, svgIndex);

                return half4(result, _BackgroundColor.a);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
