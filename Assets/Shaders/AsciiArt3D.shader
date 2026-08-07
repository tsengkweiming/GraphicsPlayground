Shader "Hidden/ASCII Art 3D"
{
    Properties
    {
        [MainTexture] _MainTex ("Reference Image", 2D) = "white" {}

        _Pattern0 ("Pattern 0 (Darkest)", 2D) = "white" {}
        _Pattern1 ("Pattern 1", 2D) = "white" {}
        _Pattern2 ("Pattern 2", 2D) = "white" {}
        _Pattern3 ("Pattern 3", 2D) = "white" {}
        _Pattern4 ("Pattern 4", 2D) = "white" {}
        _Pattern5 ("Pattern 5", 2D) = "white" {}
        _Pattern6 ("Pattern 6", 2D) = "white" {}
        _Pattern7 ("Pattern 7", 2D) = "white" {}
        _Pattern8 ("Pattern 8", 2D) = "white" {}
        _Pattern9 ("Pattern 9 (Brightest)", 2D) = "white" {}

        _PatternCount ("Total Pattern Count", Range(1, 10)) = 5
        _TextureCount ("Texture Pattern Count", Range(0, 10)) = 4
        _PatternColor ("Pattern Color", Color) = (0, 0, 0, 1)
        _PatternBackgroundColor ("Pattern Background Color", Color) = (1, 1, 1, 1)

        _PosterizeLevels ("Posterize Levels", Range(1, 50)) = 5
        _InputBlack ("Input Black Point", Range(0, 1)) = 0
        _InputWhite ("Input White Point", Range(0, 1)) = 1
        _Gamma ("Gamma", Range(0.1, 5)) = 1
        _Contrast ("Contrast", Range(0, 4)) = 1
        _Brightness ("Brightness", Range(-1, 1)) = 0
        [Toggle] _InvertLuma ("Invert Luminance", Float) = 0

        _HueShift ("Hue Shift", Range(0, 1)) = 0
        _Saturation ("Saturation", Range(0, 2)) = 1
        _Value ("Value (Brightness)", Range(0, 2)) = 1

        _DepthLighting ("Cube Face Shading", Range(0, 1)) = 0.35
        _AmbientStrength ("Ambient Light Strength", Range(0, 2)) = 1
        _DirectLightStrength ("Direct Light Strength", Range(0, 2)) = 1
        _PhaseSpeed ("Mono Phase Speed", Float) = 0.1
        [Toggle] _FlipY ("Flip Y Axis", Float) = 0

        [HideInInspector] _GridColumns ("Grid Columns", Float) = 1
        [HideInInspector] _GridRows ("Grid Rows", Float) = 1
        [HideInInspector] _InstanceBaseIndex ("Instance Base Index", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
        }

        LOD 100
        Cull Back
        ZWrite On

        Pass
        {
            Name "AsciiArt3DPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Shadows.hlsl uses this URP helper, but this lightweight pass does
            // not include the full Lit material include chain.
            real LerpWhiteTo(real value, real strength)
            {
                return lerp(1.0, value, strength);
            }

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/AmbientProbe.hlsl"
            #include "Assets/Shaders/Common/Pattern.hlsl"
            #include "Assets/Shaders/Common/Level.hlsl"
            #include "Assets/Shaders/Common/MonoPhase.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 globalUv : TEXCOORD1;
                nointerpolation float2 cellCenterUv : TEXCOORD2;
                float3 normalOS : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float3 normalWS : TEXCOORD5;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord : TEXCOORD6;
                #endif
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
            TEXTURE2D(_Pattern5);
            SAMPLER(sampler_Pattern5);
            TEXTURE2D(_Pattern6);
            SAMPLER(sampler_Pattern6);
            TEXTURE2D(_Pattern7);
            SAMPLER(sampler_Pattern7);
            TEXTURE2D(_Pattern8);
            SAMPLER(sampler_Pattern8);
            TEXTURE2D(_Pattern9);
            SAMPLER(sampler_Pattern9);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Pattern0_ST;
                float4 _Pattern1_ST;
                float4 _Pattern2_ST;
                float4 _Pattern3_ST;
                float4 _Pattern4_ST;
                float4 _Pattern5_ST;
                float4 _Pattern6_ST;
                float4 _Pattern7_ST;
                float4 _Pattern8_ST;
                float4 _Pattern9_ST;
                half4 _PatternColor;
                half4 _PatternBackgroundColor;
                float _PatternCount;
                float _TextureCount;
                float _PosterizeLevels;
                float _DepthLighting;
                float _AmbientStrength;
                float _DirectLightStrength;
                float _FlipY;
                float _GridColumns;
                float _GridRows;
                float _InstanceBaseIndex;
            CBUFFER_END

            Varyings Vertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float columns = max(_GridColumns, 1.0);
                float rows = max(_GridRows, 1.0);
                float globalIndex = (float)input.instanceID + max(_InstanceBaseIndex, 0.0);
                float2 cellId = float2(fmod(globalIndex, columns), floor(globalIndex / columns));
                float2 gridSize = float2(columns, rows);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    output.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                output.uv = input.uv;
                output.globalUv = (cellId + 1- input.uv) / gridSize;
                output.cellCenterUv = (cellId + 0.5) / gridSize;
                output.cellCenterUv.y = lerp(output.cellCenterUv.y, 1.0 - output.cellCenterUv.y, step(0.5, _FlipY));
                output.normalOS = input.normalOS;
                return output;
            }

            float Posterize(float brightness, float levels)
            {
                float stepSize = 1.0 / max(levels, 1.0);
                return floor(brightness / stepSize) * stepSize;
            }

            int GetIndex(float brightness, int numPatterns)
            {
                int safeCount = max(numPatterns, 1);
                int index = (int)floor(saturate(brightness) * safeCount);
                return clamp(index, 0, safeCount - 1);
            }

            half3 AsciiLightingLambert(half3 lightColor, half3 lightDirection, half3 normalWS)
            {
                return lightColor * saturate(dot(normalWS, lightDirection));
            }

            half3 SampleTexturePattern(float2 uv, int patternIndex)
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
                else if (patternIndex == 4)
                    color = SAMPLE_TEXTURE2D(_Pattern4, sampler_Pattern4, uv).rgb;
                else if (patternIndex == 5)
                    color = SAMPLE_TEXTURE2D(_Pattern5, sampler_Pattern5, uv).rgb;
                else if (patternIndex == 6)
                    color = SAMPLE_TEXTURE2D(_Pattern6, sampler_Pattern6, uv).rgb;
                else if (patternIndex == 7)
                    color = SAMPLE_TEXTURE2D(_Pattern7, sampler_Pattern7, uv).rgb;
                else if (patternIndex == 8)
                    color = SAMPLE_TEXTURE2D(_Pattern8, sampler_Pattern8, uv).rgb;
                else
                    color = SAMPLE_TEXTURE2D(_Pattern9, sampler_Pattern9, uv).rgb;

                return color;
            }

            half3 SampleProceduralPattern(float2 uv, int proceduralIndex, float darkness)
            {
                float seed = (float)proceduralIndex + 1.0;
                float style = floor(hash11(seed * 17.31) * 4.0);
                float scale = lerp(3.0, 11.0, hash11(seed * 29.17));
                float phase = hash11(seed * 43.73);
                float mask;

                if (style < 1.0)
                {
                    float radius = 0.5 * sqrt(saturate(darkness) / 0.78539816);
                    mask = pattern_circle_mask(uv, scale, radius, _Time.y * 0.08 * phase);
                }
                else if (style < 2.0)
                {
                    mask = step(frac(uv.x * scale + phase + _Time.y * 0.03), darkness);
                }
                else if (style < 3.0)
                {
                    mask = pattern_random_mask(uv, scale, seed, darkness);
                }
                else
                {
                    float diagonal = frac(dot(uv, normalize(float2(1.0, 1.0)) * scale) + phase);
                    mask = step(diagonal, darkness);
                }

                return lerp(_PatternBackgroundColor.rgb, _PatternColor.rgb, saturate(mask));
            }

            half3 SamplePattern(float2 uv, int patternIndex, int patternCount, int textureCount)
            {
                int safeCount = max(patternCount, 1);
                int safeTextureCount = clamp(textureCount, 0, safeCount);

                if (patternIndex < safeTextureCount)
                    return SampleTexturePattern(uv, patternIndex);

                int proceduralIndex = patternIndex - safeTextureCount;
                float darkness = 1.0 - (float)patternIndex / max((float)(safeCount - 1), 1.0);
                return SampleProceduralPattern(uv, proceduralIndex, darkness);
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 sampleUv = input.cellCenterUv * _MainTex_ST.xy + _MainTex_ST.zw;
                half3 referenceColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(sampleUv)).rgb;
                float brightness = dot(referenceColor, float3(0.299, 0.587, 0.114));
                brightness = AdjustLuminance(brightness);

                int patternCount = clamp((int)round(_PatternCount), 1, 10);
                int textureCount = clamp((int)round(_TextureCount), 0, patternCount);
                int patternIndex = GetIndex(Posterize(brightness, _PosterizeLevels), patternCount);

                half3 patternColor = SamplePattern(input.uv, patternIndex, patternCount, textureCount);
                patternColor = ApplyHsvShift(patternColor);

                float2 fullUv = input.globalUv;
                fullUv.y = lerp(fullUv.y, 1.0 - fullUv.y, step(0.5, _FlipY));
                half3 sourceColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(fullUv)).rgb;
                float phase = mono_phase(fullUv, _Time.y);
                half3 result = lerp(sourceColor, patternColor, phase);

                float3 normalWS = normalize(input.normalWS);
                float4 shadowCoord = 0.0;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif

                Light mainLight = GetMainLight(shadowCoord);
                half3 lighting = SampleSH(normalWS) * _AmbientStrength;
                lighting += AsciiLightingLambert(
                    mainLight.color * mainLight.shadowAttenuation,
                    mainLight.direction,
                    normalWS) * _DirectLightStrength;

                #if defined(_ADDITIONAL_LIGHTS)
                    uint additionalLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < additionalLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, input.positionWS);
                        lighting += AsciiLightingLambert(
                            light.color * light.distanceAttenuation * light.shadowAttenuation,
                            light.direction,
                            normalWS) * _DirectLightStrength;
                    }
                #endif

                // Preserve the frontal face while darkening side faces enough
                // to reveal that the original 2D cells are thin cubes.
                float sideAmount = 1.0 - abs(input.normalOS.z);
                float faceShade = 1.0 - sideAmount * _DepthLighting;
                return half4(result * lighting * faceShade, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            real LerpWhiteTo(real value, real strength)
            {
                return lerp(1.0, value, strength);
            }
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
