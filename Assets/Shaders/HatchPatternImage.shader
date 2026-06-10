Shader "Hidden/Procedural/Hatch Pattern Image"
{
    Properties
    {
        [MainTexture] _BaseMap ("Source Image", 2D) = "white" {}
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)

        _Ink0 ("Ink 0 - Cross", Color) = (1.0, 0.733333, 0.733333, 1)
        _Ink1 ("Ink 1 - Diagonal", Color) = (0.8, 0.8, 0.8, 1)
        _Ink2 ("Ink 2 - Vertical Diagonal", Color) = (0.933333, 0.933333, 0.0, 1)
        _Ink3 ("Ink 3 - Diagonal Cross", Color) = (0.0, 0.666667, 1.0, 1)

        _Resolution ("Columns", Range(5, 160)) = 70
        _ColorDivisions ("Color Divisions", Range(1, 4)) = 4
        _StrokeWeight ("Stroke Weight (p5 px)", Range(0.25, 16)) = 2
        _ReferenceWidth ("Reference Canvas Width", Float) = 736
        _CanvasAspect ("Canvas Aspect Width / Height", Float) = 0.71875
        _Angle ("Angle Degrees", Range(0, 360)) = 0
        _BrightnessLift ("Brightness Lift", Range(0, 1)) = 0
        _CoverageSoftness ("Coverage Softness", Range(0.25, 3)) = 1
        [Toggle] _FlipSourceY ("Flip Source Y", Float) = 0
        [Toggle] _ShowSource ("Show Source Debug", Float) = 0
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
            Name "HatchPatternImage"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex HatchVertex
            #pragma fragment HatchFragment
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/Common/HatchPatterns.hlsl"

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

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BackgroundColor;
                half4 _Ink0;
                half4 _Ink1;
                half4 _Ink2;
                half4 _Ink3;
                float _Resolution;
                float _ColorDivisions;
                float _StrokeWeight;
                float _ReferenceWidth;
                float _CanvasAspect;
                float _Angle;
                float _BrightnessLift;
                float _CoverageSoftness;
                float _FlipSourceY;
                float _ShowSource;
            CBUFFER_END

            Varyings HatchVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float2 HatchSourceUv(float2 canvasUv)
            {
                float2 sourceUv = float2(canvasUv.x, 1.0 - canvasUv.y);
                sourceUv = sourceUv * _BaseMap_ST.xy + _BaseMap_ST.zw;
                sourceUv.y = lerp(sourceUv.y, 1.0 - sourceUv.y, step(0.5, _FlipSourceY));
                return sourceUv;
            }

            void HatchEvaluateLayer(
                float2 uv,
                float2 cellId,
                float2 gridSize,
                float angleRadians,
                float strokeWidthCell,
                inout half3 color)
            {
                float validCell = HatchCellIsValid(cellId, gridSize);

                float2 localUv = uv * gridSize - cellId;
                localUv = HatchRotate2D(localUv - 0.5, -angleRadians) + 0.5;

                float2 cellSampleUv = HatchSourceUv(HatchCellCenterUv(cellId, gridSize));
                half3 sourceColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, saturate(cellSampleUv)).rgb;

                float brightness = HatchP5Brightness(sourceColor, _BrightnessLift);
                float patternIndex = HatchQuantizeDarkness(brightness, _ColorDivisions);
                float mask = HatchPatternMask(localUv, patternIndex, strokeWidthCell, _CoverageSoftness) * validCell;

                half3 inkColor = (half3)HatchPaletteColor(patternIndex, _Ink0.rgb, _Ink1.rgb, _Ink2.rgb, _Ink3.rgb);
                color = lerp(color, inkColor, saturate(mask));
            }

            half4 HatchFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = saturate(float2(input.uv.x, 1.0 - input.uv.y));
                float2 gridSize = HatchGridFromColumns(_Resolution, _CanvasAspect);
                float2 baseCellId = floor(uv * gridSize);
                float angleRadians = radians(_Angle);
                float strokeWidthCell = HatchStrokeWidthInCell(_StrokeWeight, _ReferenceWidth, _Resolution);

                half3 color = _BackgroundColor.rgb;

                [unroll]
                for (int x = -1; x <= 1; x++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        float2 cellId = baseCellId + float2((float)x, (float)y);
                        HatchEvaluateLayer(uv, cellId, gridSize, angleRadians, strokeWidthCell, color);
                    }
                }

                half3 sourceDebug = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, HatchSourceUv(uv)).rgb;
                color = lerp(color, sourceDebug, step(0.5, _ShowSource));

                return half4(color, _BackgroundColor.a);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
