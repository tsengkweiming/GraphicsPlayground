Shader "Hidden/ASCII Art"
{
    Properties
    {
        [MainTexture] _MainTex ("Reference Image", 2D) = "white" {}

        // Pattern slots are ordered from darkest to brightest.
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
        _Resolution ("Maximum Quad Columns", Range(10, 350)) = 60
        _PosterizeLevels ("Posterize Levels", Range(-2, 50)) = 5
        _QuadTreeThreshold ("Quad Tree Brightness Stop", Range(0, 1)) = 0.5
        _QuadTreeMinDivisions ("Quad Tree Minimum Horizontal Divisions", Range(1, 32)) = 4
        _QuadTreeMaxIterations ("Quad Tree Maximum Depth", Range(1, 8)) = 6

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
                float _Resolution;
                float _PosterizeLevels;
                float _PatternCount;
                float _TextureCount;
                float _QuadTreeThreshold;
                float _QuadTreeMinDivisions;
                float _QuadTreeMaxIterations;
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

            // Map brightness (0-1) to a slot ordered from darkest to brightest.
            int GetIndex(float brightness, int numPatterns)
            {
                int safeCount = max(numPatterns, 1);
                int index = int(floor(saturate(brightness) * safeCount));
                return clamp(index, 0, safeCount - 1);
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

            // Return a procedural pattern whose expected black coverage is
            // controlled by darkness. The pattern slot, not the source RGB,
            // determines darkness, so GetIndex remains the single selector.
            half3 SampleProceduralPattern(float2 uv, int proceduralIndex, float darkness)
            {
                float seed = (float)proceduralIndex + 1.0;
                float style = floor(hash11(seed * 17.31) * 4.0);
                float scale = lerp(3.0, 11.0, hash11(seed * 29.17));
                float phase = hash11(seed * 43.73);
                float mask;

                if (style < 1.0)
                {
                    // Animated circles. Radius is area-matched to the target
                    // darkness for the normal circle range.
                    float radius = 0.5 * sqrt(saturate(darkness) / 0.78539816);
                    mask = pattern_circle_mask(uv, scale, radius, _Time.y * 0.08 * phase);
                }
                else if (style < 2.0)
                {
                    // A stripe field has a direct duty-cycle/darkness mapping.
                    mask = step(frac(uv.x * scale + phase + _Time.y * 0.03), darkness);
                }
                else if (style < 3.0)
                {
                    // Cell noise gives a stable random pattern per ASCII cell.
                    mask = pattern_random_mask(uv, scale, seed, darkness);
                }
                else
                {
                    // Diagonal bands provide a second continuous coverage field.
                    float diagonal = frac(dot(uv, normalize(float2(1.0, 1.0)) * scale) + phase);
                    mask = step(diagonal, darkness);
                }

                return lerp(_PatternBackgroundColor, _PatternColor, saturate(mask));
            }

            // The first TextureCount slots sample textures. The remaining
            // slots are procedural, while retaining the same darkness ladder.
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

                // Derivatives describe how much UV space one screen pixel
                // covers on this actual mesh. Unlike _ScaledScreenParams,
                // this remains correct when the quad is square, 16:9, scaled,
                // or rendered into a different-size target.
                float uvPerPixelX = max(length(ddx(uv)), 1e-6);
                float uvPerPixelY = max(length(ddy(uv)), 1e-6);
                float aspect = uvPerPixelY / uvPerPixelX;
                
                // Keep adaptive quadtree cells close to square in screen
                // space. Use the actual quad aspect rather than the camera
                // target aspect, because this shader can render on a square
                // or 16:9 mesh independently of the render target.
                float shortAxisDivisions = max(round(_QuadTreeMinDivisions), 1.0);
                float2 landscapeDivisions = float2(
                    max(round(shortAxisDivisions * aspect), 1.0),
                    shortAxisDivisions);
                float2 portraitDivisions = float2(
                    shortAxisDivisions,
                    max(round(shortAxisDivisions / max(aspect, 0.0001)), 1.0));
                float2 minQuadDivisions = lerp(
                    portraitDivisions,
                    landscapeDivisions,
                    step(1.0, aspect));

                // _Resolution is the maximum horizontal detail requested by
                // the controller. Since the tree doubles at every level, the
                // nearest power-of-two depth is used as the actual cap.
                float resolutionRatio = max(
                    _Resolution / max(minQuadDivisions.x, 1.0),
                    1.0);
                int resolutionIterations = 1 + (int)round(log2(resolutionRatio));
                int maxTreeIterations = min(
                    (int)round(_QuadTreeMaxIterations),
                    resolutionIterations);

                // Query from the current pixel, not the old fixed-grid cell
                // center. This guarantees that the selected leaf, its outline,
                // and the pattern UV all refer to the same quadtree node.
                float2 analysisUv = uv;
                BrightnessQuadResult quad = FindBrightnessQuadTree(
                    _MainTex,
                    sampler_MainTex,
                    analysisUv,
                    minQuadDivisions,
                    maxTreeIterations,
                    _QuadTreeThreshold);
                // Draw the boundary of the selected adaptive quad. _ScaledScreenParams
                // is intentionally not used here: the line width must follow
                // the rendered quad, not the camera render-target resolution.
                float2 normalizedQuadUV = frac(uv * quad.divisions);
                float2 lineWidthUV = _LineWidth * float2(uvPerPixelX, uvPerPixelY);
                float2 distanceToEdge = min(normalizedQuadUV, 1.0 - normalizedQuadUV);
                float lineMask =
                    max(
                        step(distanceToEdge.x, lineWidthUV.x * quad.divisions.x),
                        step(distanceToEdge.y, lineWidthUV.y * quad.divisions.y));

                float lineBlend = saturate(lineMask * _LineStrength);

                // Calculate brightness (0-1)
                float brightness = quad.brightness;

                // Remap tonal range so more of the pattern set is used
                brightness = AdjustLuminance(brightness);

                // Posterize brightness
                float posterized = Posterize(brightness, _PosterizeLevels);

                int patternCount = clamp((int)round(_PatternCount), 1, 10);
                int textureCount = clamp((int)round(_TextureCount), 0, patternCount);

                // Map to the configured pattern ladder.
                int imgIndex = GetIndex(posterized, patternCount);

                // Sample the pattern in the selected quadtree leaf. This makes
                // its width and height match the outlined quad at every depth.
                float2 quadUv = frac(uv * quad.divisions);
                half3 result = SamplePattern(quadUv, imgIndex, patternCount, textureCount);

                // Apply HSV shift
                result = ApplyHsvShift(result);

                half3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, saturate(uv)).rgb;
                float index = mono_phase(uv, _Time.y);
                half3 output = lerp(color, result, index);
                output = lerp(output, (half3)_LineColor.rgb, lineBlend);
                return half4(output, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
