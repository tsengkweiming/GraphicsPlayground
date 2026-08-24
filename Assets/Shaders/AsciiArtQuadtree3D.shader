Shader "Hidden/ASCII Art Quadtree 3D"
{
    Properties
    {
        [MainTexture] _MainTex ("Reference Image", 2D) = "white" {}

        _Pattern0 ("Pattern 0 (Darkest)", 2D) = "white" {}
        [HideInInspector] _Pattern1 ("Pattern 1", 2D) = "white" {}
        [HideInInspector] _Pattern2 ("Pattern 2", 2D) = "white" {}
        [HideInInspector] _Pattern3 ("Pattern 3", 2D) = "white" {}
        [HideInInspector] _Pattern4 ("Pattern 4", 2D) = "white" {}
        [HideInInspector] _Pattern5 ("Pattern 5", 2D) = "white" {}
        [HideInInspector] _Pattern6 ("Pattern 6", 2D) = "white" {}
        [HideInInspector] _Pattern7 ("Pattern 7", 2D) = "white" {}
        [HideInInspector] _Pattern8 ("Pattern 8", 2D) = "white" {}
        [HideInInspector] _Pattern9 ("Pattern 9 (Brightest)", 2D) = "white" {}

        _PatternCount ("Total Pattern Count", Range(1, 10)) = 5
        _TextureCount ("Texture Pattern Count", Range(0, 10)) = 4
        _PatternColor ("Pattern Color", Color) = (0, 0, 0, 1)
        _PatternBackgroundColor ("Pattern Background Color", Color) = (1, 1, 1, 1)
        _LineColor ("Grid Line Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _LineWidth ("Grid Line Width (Pixels)", Range(0.0, 4.0)) = 1.0
        _LineStrength ("Grid Line Strength", Range(0.0, 1.0)) = 1.0

        _InputBlack ("Input Black Point", Range(0, 1)) = 0
        _InputWhite ("Input White Point", Range(0, 1)) = 1
        _Gamma ("Gamma", Range(0.1, 5)) = 1
        _Contrast ("Contrast", Range(0, 4)) = 1
        _Brightness ("Brightness", Range(-1, 1)) = 0
        [Toggle] _InvertLuma ("Invert Luminance", Float) = 0
        _PosterizeLevel ("Posterize Levels", Range(1, 50)) = 5
        _HueShift ("Hue Shift", Range(0, 1)) = 0
        _Saturation ("Saturation", Range(0, 2)) = 1
        _Value ("Value (Brightness)", Range(0, 2)) = 1
        _PhaseSpeed ("Phase Speed", Float) = 0.1
        [Toggle] _FlipY ("Flip Y Axis", Float) = 0

        _QuadTreeMinDivisions ("Minimum Short-Axis Divisions", Range(1, 32)) = 4
        _QuadTreeMaxIterations ("Maximum Quadtree Depth", Range(1, 8)) = 6
        _QuadTreeThreshold ("Brightness Stop Threshold", Range(0, 1)) = 0.5
        
        _ColorTexUvIndex ("ColorTex Uv Index", Range(0, 1)) = 0

        _DepthLighting ("Cube Face Shading", Range(0, 1)) = 0.35
        _AmbientStrength ("Ambient Light Strength", Range(0, 2)) = 1
        _DirectLightStrength ("Direct Light Strength", Range(0, 2)) = 1
        _DepthMotionAmplitude ("Depth Motion Amplitude", Float) = 0
        _DepthMotionSpeed ("Depth Motion Speed", Float) = 1
        _RotationAmplitude ("Rotation Amplitude (Radians)", Float) = 0
        _MotionActiveThreshold ("Motion Active Threshold", Range(0, 1)) = 0

        [HideInInspector] _GridColumns ("Grid Columns", Float) = 60
        [HideInInspector] _GridRows ("Grid Rows", Float) = 34
        [HideInInspector] _GridAspect ("Grid Aspect", Float) = 1.777
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

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/Common/Random.hlsl"
            #include "Assets/Shaders/Common/Pattern.hlsl"
            #include "Assets/Shaders/Common/Transform.hlsl"
            #include "Assets/Shaders/Common/QuadTree.hlsl"

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

            // RealtimeLights.hlsl expects this helper when the lightweight
            // material include chain is not used.
            real LerpWhiteTo(real value, real strength)
            {
                return lerp(1.0, value, strength);
            }

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
                float4 _LineColor;
                float _LineWidth;
                float _LineStrength;
                float _PatternCount;
                float _TextureCount;
                float _PosterizeLevel;
                float _FlipY;
                float _QuadTreeMinDivisions;
                float _QuadTreeMaxIterations;
                float _QuadTreeThreshold;
                float _DepthLighting;
                float _AmbientStrength;
                float _DirectLightStrength;
                float _DepthMotionAmplitude;
                float _DepthMotionSpeed;
                float _RotationAmplitude;
                float _MotionActiveThreshold;
                float _GridColumns;
                float _GridRows;
                float _GridAspect;
                float _InstanceBaseIndex;
                float _ColorTexUvIndex;
            CBUFFER_END

            struct AdaptiveLeaf
            {
                BrightnessQuadResult quad;
                float2 gridSize;
                float2 cellCenter;
                float keep;
            };

            float2 MinimumQuadDivisions()
            {
                float shortAxis = max(round(_QuadTreeMinDivisions), 1.0);
                float2 landscape = float2(
                    max(round(shortAxis * _GridAspect), 1.0),
                    shortAxis);
                float2 portrait = float2(
                    shortAxis,
                    max(round(shortAxis / max(_GridAspect, 0.0001)), 1.0));
                return lerp(portrait, landscape, step(1.0, _GridAspect));
            }

            int MaximumQuadIterations(float2 minDivisions)
            {
                float ratio = max(_GridColumns / max(minDivisions.x, 1.0), 1.0);
                int resolutionDepth = 1 + (int)round(log2(ratio));
                return min((int)round(_QuadTreeMaxIterations), resolutionDepth);
            }

            float2 SourceUv(float2 uv)
            {
                uv.y = lerp(uv.y, 1.0 - uv.y, step(0.5, _FlipY));
                return uv;
            }

            AdaptiveLeaf GetAdaptiveLeaf(uint instanceID)
            {
                AdaptiveLeaf result;
                result.gridSize = float2(max(_GridColumns, 1.0), max(_GridRows, 1.0));

                float globalIndex = (float)instanceID + max(_InstanceBaseIndex, 0.0);
                float2 cellId = float2(
                    fmod(globalIndex, result.gridSize.x),
                    floor(globalIndex / result.gridSize.x));
                result.cellCenter = (cellId + 0.5) / result.gridSize;

                float2 minDivisions = MinimumQuadDivisions();
                result.quad = FindBrightnessQuadTreeLod(
                    _MainTex,
                    sampler_MainTex,
                    SourceUv(result.cellCenter),
                    minDivisions,
                    MaximumQuadIterations(minDivisions),
                    _QuadTreeThreshold);
                result.quad.center = SourceUv(result.quad.center);

                float2 representativeCell = floor(result.quad.center * result.gridSize);
                float cellDistance = abs(cellId.x - representativeCell.x) +
                                     abs(cellId.y - representativeCell.y);
                result.keep = step(cellDistance, 0.5);
                return result;
            }

            float3 LeafPositionOS(float3 positionOS, AdaptiveLeaf leaf)
            {
                float2 leafCells = max(leaf.quad.size * leaf.gridSize, 1.0);
                float2 leafOffset = (leaf.quad.center - leaf.cellCenter) * leaf.gridSize;
                positionOS.xy = positionOS.xy * leafCells + leafOffset;
                return positionOS;
            }

            float3 InstanceMotionData(float instanceID, float threshold)
            {
                float hash1 = hash11(instanceID * 17.13 + 4.71);
                float phase = hash1 * 6.2831853;
                float frequency = lerp(0.8, 1.2, hash11(instanceID * 31.79 + 9.23));
                float active = step(threshold, hash1);
                return float3(active, phase, frequency);
            }

            float3 RotateInstanceCenter(float3 positionWS, float3 centerWS, float angle)
            {
                return centerWS + mul(RotateZ(angle), positionWS - centerWS);
            }

            float Posterize(float brightness, float levels)
            {
                float stepSize = 1.0 / max(levels, 1.0);
                return floor(brightness / stepSize) * stepSize;
            }

            int GetPatternIndex(float brightness, int patternCount)
            {
                int safeCount = max(patternCount, 1);
                return clamp((int)floor(saturate(brightness) * safeCount), 0, safeCount - 1);
            }

            half3 SampleTexturePattern(float2 uv, int patternIndex)
            {
                half3 color = SAMPLE_TEXTURE2D(_Pattern9, sampler_Pattern9, uv).rgb;
                if (patternIndex == 0) color = SAMPLE_TEXTURE2D(_Pattern0, sampler_Pattern0, uv).rgb;
                else if (patternIndex == 1) color = SAMPLE_TEXTURE2D(_Pattern1, sampler_Pattern1, uv).rgb;
                else if (patternIndex == 2) color = SAMPLE_TEXTURE2D(_Pattern2, sampler_Pattern2, uv).rgb;
                else if (patternIndex == 3) color = SAMPLE_TEXTURE2D(_Pattern3, sampler_Pattern3, uv).rgb;
                else if (patternIndex == 4) color = SAMPLE_TEXTURE2D(_Pattern4, sampler_Pattern4, uv).rgb;
                else if (patternIndex == 5) color = SAMPLE_TEXTURE2D(_Pattern5, sampler_Pattern5, uv).rgb;
                else if (patternIndex == 6) color = SAMPLE_TEXTURE2D(_Pattern6, sampler_Pattern6, uv).rgb;
                else if (patternIndex == 7) color = SAMPLE_TEXTURE2D(_Pattern7, sampler_Pattern7, uv).rgb;
                else if (patternIndex == 8) color = SAMPLE_TEXTURE2D(_Pattern8, sampler_Pattern8, uv).rgb;
                return color;
            }

            half3 SampleProceduralPattern(float2 uv, int patternIndex, float darkness)
            {
                float seed = (float)patternIndex + 1.0;
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

                return lerp(_PatternBackgroundColor, _PatternColor, saturate(mask));
            }

            half3 SamplePattern(float2 uv, int patternIndex, int patternCount, int textureCount)
            {
                int safeCount = max(patternCount, 1);
                int safeTextureCount = clamp(textureCount, 0, safeCount);
                if (patternIndex < safeTextureCount)
                    return SampleTexturePattern(uv, patternIndex);

                float darkness = 1.0 - (float)patternIndex / max((float)(safeCount - 1), 1.0);
                return SampleProceduralPattern(uv, patternIndex - safeTextureCount, darkness);
            }
        ENDHLSL

        Pass
        {
            Name "AsciiArtQuadtree3DPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/AmbientProbe.hlsl"
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
                nointerpolation float2 leafCenterUv : TEXCOORD1;
                nointerpolation float leafBrightness : TEXCOORD2;
                nointerpolation float keep : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float3 normalWS : TEXCOORD5;
                float3 normalOS : TEXCOORD6;
                float2 globalUv : TEXCOORD8;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                AdaptiveLeaf leaf = GetAdaptiveLeaf(input.instanceID);
                float globalIndex = (float)input.instanceID + max(_InstanceBaseIndex, 0.0);
                float3 motion = InstanceMotionData(globalIndex, _MotionActiveThreshold);
                float motionSignal = motion.x * sin(_Time.y * _DepthMotionSpeed * motion.z + motion.y);

                float3 positionWS = TransformObjectToWorld(LeafPositionOS(input.positionOS.xyz, leaf));
                float3 centerWS = TransformObjectToWorld(float3(0.0, 0.0, 0.0));
                positionWS = RotateInstanceCenter(
                    positionWS,
                    centerWS,
                    motionSignal * _RotationAmplitude);
                float3 depthDirectionWS = normalize(TransformObjectToWorldDir(float3(0.0, 0.0, 1.0)));
                positionWS += depthDirectionWS * motionSignal * _DepthMotionAmplitude;

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                normalInput.normalWS = normalize(mul(
                    RotateZ(motionSignal * _RotationAmplitude),
                    normalInput.normalWS));

                output.positionCS = TransformWorldToHClip(positionWS);
                output.positionCS = lerp(output.positionCS, float4(2.0, 2.0, 0.0, 1.0), 1.0 - leaf.keep);
                output.positionWS = positionWS;
                output.normalWS = normalInput.normalWS;
                output.normalOS = input.normalOS;
                output.uv = input.uv;
                output.leafCenterUv = leaf.quad.center;
                output.leafBrightness = leaf.quad.brightness;
                output.keep = leaf.keep;
                // Expand the adaptive leaf across the cube face. The
                // reversed local offset matches AsciiArt3D.shader's cube UV
                // orientation and restores a continuous image-space UV.
                output.globalUv = leaf.quad.center +
                                  (0.5 - input.uv) * leaf.quad.size;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                clip(input.keep - 0.5);

                float brightness = AdjustLuminance(input.leafBrightness);
                int patternCount = clamp((int)round(_PatternCount), 1, 10);
                int textureCount = clamp((int)round(_TextureCount), 0, patternCount);
                int patternIndex = GetPatternIndex(
                    Posterize(brightness, _PosterizeLevel),
                    patternCount);

                half3 patternColor = ApplyHsvShift(
                    SamplePattern(input.uv, patternIndex, patternCount, textureCount));
                float2 fullUv = lerp(input.leafCenterUv, input.globalUv, _ColorTexUvIndex);
                float2 sampleUv = fullUv * _MainTex_ST.xy + _MainTex_ST.zw;
                half3 sourceColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(sampleUv)).rgb;
                half3 result = lerp(sourceColor, patternColor, mono_phase(fullUv, _Time.y));

                // Outline each adaptive cube face in screen-space pixels.
                // fwidth(input.uv) converts the requested pixel width into
                // the current cube's UV space, so the line remains stable as
                // quadtree leaves change size or move in depth.
                float2 distanceToEdge = min(input.uv, 1.0 - input.uv);
                float2 lineWidthUV = _LineWidth * max(fwidth(input.uv), 1e-5);
                float lineMask = max(
                    step(distanceToEdge.x, lineWidthUV.x),
                    step(distanceToEdge.y, lineWidthUV.y));
                float lineBlend = saturate(lineMask * _LineStrength);

                float4 shadowCoord = 0.0;
                #if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif

                Light mainLight = GetMainLight(shadowCoord);
                half3 lighting = SampleSH(normalize(input.normalWS)) * _AmbientStrength;
                lighting += mainLight.color * mainLight.shadowAttenuation *
                             saturate(dot(normalize(input.normalWS), mainLight.direction)) *
                             _DirectLightStrength;

                #if defined(_ADDITIONAL_LIGHTS)
                    uint additionalLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < additionalLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, input.positionWS);
                        lighting += light.color * light.distanceAttenuation * light.shadowAttenuation *
                                     saturate(dot(normalize(input.normalWS), light.direction)) *
                                     _DirectLightStrength;
                    }
                #endif

                float sideAmount = 1.0 - abs(input.normalOS.z);
                float faceShade = 1.0 - sideAmount * _DepthLighting;
                half3 litResult = result * lighting * faceShade;
                litResult = lerp(litResult, (half3)_LineColor.rgb, lineBlend);
                return half4(litResult, 1.0);
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
            #pragma target 4.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                uint instanceID : SV_InstanceID;
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
                nointerpolation float keep : TEXCOORD0;
            };

            ShadowVaryings ShadowVert(ShadowAttributes input)
            {
                ShadowVaryings output;
                UNITY_SETUP_INSTANCE_ID(input);

                AdaptiveLeaf leaf = GetAdaptiveLeaf(input.instanceID);
                float3 positionWS = TransformObjectToWorld(LeafPositionOS(input.positionOS.xyz, leaf));
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                output.positionCS = TransformWorldToHClip(
                    ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                output.positionCS = lerp(output.positionCS, float4(2.0, 2.0, 0.0, 1.0), 1.0 - leaf.keep);
                output.keep = leaf.keep;
                return output;
            }

            half4 ShadowFrag(ShadowVaryings input) : SV_TARGET
            {
                clip(input.keep - 0.5);
                return 0;
            }
            ENDHLSL
        }
    }
}
