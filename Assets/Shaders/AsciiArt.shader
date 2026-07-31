Shader "Hidden/ASCII Art"
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
        _Resolution ("Resolution (Grid Columns)", Range(10, 150)) = 59
        _PosterizeLevels ("Posterize Levels", Range(-2, 50)) = 5
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

            // Posterize function: reduce brightness levels
            float Posterize(float brightness, float levels)
            {
                float step = 1.0 / levels;
                return floor(brightness / step) * step;
            }

            // Map brightness (0-1) to SVG pattern index (0-4)
            int GetSVGIndex(float brightness, int numPatterns)
            {
                // Invert: darker -> lower index (more detail)
                float inverted = 1.0 - brightness;
                int index = int(floor(inverted * numPatterns));
                return clamp(index, 0, numPatterns - 1);
            }

            // Sample the appropriate SVG pattern based on brightness
            half3 SampleSVGPattern(float2 uv, int patternIndex)
            {
                half3 color = half3(1, 1, 1);

                if (patternIndex == 0)
                    color = SAMPLE_TEXTURE2D(_SVGPattern0, sampler_SVGPattern0, uv).rgb;
                else if (patternIndex == 1)
                    color = SAMPLE_TEXTURE2D(_SVGPattern1, sampler_SVGPattern1, uv).rgb;
                else if (patternIndex == 2)
                    color = SAMPLE_TEXTURE2D(_SVGPattern2, sampler_SVGPattern2, uv).rgb;
                else if (patternIndex == 3)
                    color = SAMPLE_TEXTURE2D(_SVGPattern3, sampler_SVGPattern3, uv).rgb;
                else
                    color = SAMPLE_TEXTURE2D(_SVGPattern4, sampler_SVGPattern4, uv).rgb;

                return color;
            }

            half4 FlowerASCIIFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Convert from Unity bottom-left to p5 top-left UV convention
                float2 canvasUv = float2(input.uv.x, 1.0 - input.uv.y);

                // Grid dimensions (similar to p5.js calculation)
                float cols = _Resolution;
                float aspectRatio = 16.0 / 9.0; // Adjust based on your canvas aspect
                float rows = floor(cols / aspectRatio);

                // Current grid cell
                float2 cellId = floor(canvasUv * float2(cols, rows));
                float2 cellUv = frac(canvasUv * float2(cols, rows));

                // Sample reference image at cell center (like p5 loop)
                float2 cellCenterUv = (cellId + 0.5) / float2(cols, rows);
                // Convert back to standard UV for texture sampling
                float2 refUv = float2(cellCenterUv.x, 1.0 - cellCenterUv.y);
                refUv = refUv * _ReferenceImage_ST.xy + _ReferenceImage_ST.zw;

                half3 refColor = SAMPLE_TEXTURE2D(_ReferenceImage, sampler_ReferenceImage, saturate(refUv)).rgb;

                // Calculate brightness (0-1)
                float brightness = dot(refColor, float3(0.299, 0.587, 0.114));

                // Posterize brightness
                float posterized = Posterize(brightness, _PosterizeLevels);

                // Map to SVG pattern index
                int svgIndex = GetSVGIndex(posterized, 5);

                // Sample the appropriate SVG pattern
                half3 result = SampleSVGPattern(cellUv, svgIndex);

                return half4(result, _BackgroundColor.a);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
