Shader "Hidden/Texture Blend Transitions"
{
    Properties
    {
        _TextureA ("Texture A", 2D) = "white" {}
        _TextureB ("Texture B", 2D) = "white" {}

        _BlendMode ("Blend Mode", Range(0, 9)) = 0
        _BlendAmount ("Blend Amount (0-1)", Range(0, 1)) = 0.5
        _TransitionSpeed ("Transition Speed", Range(0.1, 5)) = 1.0
        _NoiseScale ("Noise/Pattern Scale", Range(0.1, 10)) = 2.0
        _Distortion ("Distortion Amount", Range(0, 1)) = 0.2

        [Toggle] _UseTime ("Use Time Auto", Float) = 1
        [Toggle] _InvertTransition ("Invert Transition", Float) = 0
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
            Name "TextureBlendPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex BlendVertex
            #pragma fragment BlendFragment
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

            TEXTURE2D(_TextureA);
            SAMPLER(sampler_TextureA);
            TEXTURE2D(_TextureB);
            SAMPLER(sampler_TextureB);

            CBUFFER_START(UnityPerMaterial)
                float4 _TextureA_ST;
                float4 _TextureB_ST;
                float _BlendMode;
                float _BlendAmount;
                float _TransitionSpeed;
                float _NoiseScale;
                float _Distortion;
                float _UseTime;
                float _InvertTransition;
            CBUFFER_END

            Varyings BlendVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // ─────────────────────────────────────────────────────
            // NOISE & PATTERN GENERATORS
            // ─────────────────────────────────────────────────────

            float Hash2D(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.13);
                p3 += dot(p3, p3.yzx + 3.333);
                return frac((p3.x + p3.y) * p3.z);
            }

            float Noise2D(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                float n00 = Hash2D(i + float2(0, 0));
                float n10 = Hash2D(i + float2(1, 0));
                float n01 = Hash2D(i + float2(0, 1));
                float n11 = Hash2D(i + float2(1, 1));

                float nx0 = lerp(n00, n10, f.x);
                float nx1 = lerp(n01, n11, f.x);
                return lerp(nx0, nx1, f.y);
            }
            
            // Fractal Brownian Motion (FBM)
            float FBM(float2 uv, int octaves)
            {
                float value = 0.0;
                float amplitude = 1.0;
                float frequency = 1.0;
                float maxValue = 0.0;

                for (int i = 0; i < octaves; i++)
                {
                    value += amplitude * Noise2D(uv * frequency);
                    maxValue += amplitude;
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                return value / maxValue;
            }

            // Voronoi pattern (manhattan distance based)
            float Voronoi(float2 uv, float time)
            {
                float2 cell = floor(uv);
                float2 fract = frac(uv);
                float minDist = 1.0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(float(x), float(y));
                        float2 pt = Hash2D(cell + neighbor) * 0.8 + 0.1;
                        pt += sin(time + Hash2D(cell + neighbor) * 6.28) * 0.1;
                        float dist = distance(fract, pt + neighbor);
                        minDist = min(minDist, dist);
                    }
                }
                return minDist;
            }

            // ─────────────────────────────────────────────────────
            // TRANSITION MASKS
            // ─────────────────────────────────────────────────────

            // 1. Linear fade
            float TransitionLinear(float t)
            {
                return t;
            }

            // 2. Organic dissolve (noise-based)
            float TransitionDissolve(float2 uv, float t)
            {
                float noise = FBM(uv * _NoiseScale, 4);
                float threshold = t * 1.5 - 0.25;
                return smoothstep(threshold - 0.1, threshold + 0.1, noise);
            }

            // 3. Voronoi dither
            float TransitionVoronoi(float2 uv, float t)
            {
                float voronoi = Voronoi(uv * _NoiseScale, _Time.y);
                return smoothstep(voronoi, voronoi + 0.1, t);
            }

            // 4. Radial sweep (center outward)
            float TransitionRadialSweep(float2 uv, float t)
            {
                float2 center = float2(0.5, 0.5);
                float dist = distance(uv, center);
                float angle = atan2(uv.y - center.y, uv.x - center.x);
                return smoothstep(dist - t * 0.7, dist + 0.1, t);
            }

            // 5. Angular sweep (spiral)
            float TransitionAngularSweep(float2 uv, float t)
            {
                float2 center = float2(0.5, 0.5);
                float angle = atan2(uv.y - center.y, uv.x - center.x);
                float dist = distance(uv, center);
                return smoothstep(angle + dist - t * 3.14, angle + dist + 0.2, t * 3.14);
            }

            // 6. Stippling/halftone transition
            float TransitionStippling(float2 uv, float t)
            {
                float2 dotPos = frac(uv * _NoiseScale);
                float dotSize = t;
                float dot = smoothstep(dotSize - 0.1, dotSize, length(dotPos - 0.5));
                return dot * (1.0 - frac(Noise2D(floor(uv * _NoiseScale))));
            }

            // 7. Wave/undulation transition
            float TransitionWave(float2 uv, float t)
            {
                float wave = sin((uv.x - t) * 3.14 * 4.0 + uv.y * 2.0) * 0.5 + 0.5;
                return smoothstep(wave - t * 0.3, wave + 0.2, t);
            }

            // 8. Fractal/recursive transition
            float TransitionFractal(float2 uv, float t)
            {
                float fbm = FBM(uv * _NoiseScale * (1.0 + t * 2.0), 5);
                float spiral = atan2(uv.y - 0.5, uv.x - 0.5) / 3.14159;
                float combined = fbm + spiral * t;
                return frac(combined);
            }

            // 9. Pixel scatter transition (hash-based per-cell reveal)
            float TransitionPixelScatter(float2 uv, float t)
            {
                // Divide UV into a grid (scale by _NoiseScale for grid density)
                // _NoiseScale controls cell size: higher = larger cells = coarser scatter
                float gridScale = _NoiseScale * 8.0; // typical range 8-80 cells across
                float2 cell = floor(uv * gridScale);

                // Hash the cell to get per-block threshold [0,1]
                float cellHash = Hash2D(cell + float2(13.7, 5.3));

                // Soften the scatter with subtle noise
                float softNoise = Noise2D(uv * gridScale) * 0.04;

                // Compare progress against per-cell threshold
                // step() creates hard scatter, add softness with smoothstep if desired
                float scatter = step(cellHash, t + softNoise);

                // Optional: fade scattered pixels in/out smoothly
                // Uncomment for softer edge (costs more but smoother):
                scatter = smoothstep(cellHash - 0.03, cellHash + 0.03, t + softNoise);

                return scatter;
            }

            // ─────────────────────────────────────────────────────
            // DISTORTION EFFECTS
            // ─────────────────────────────────────────────────────

            float2 ApplyDistortion(float2 uv, float t, float distortAmount)
            {
                float noise = Noise2D(uv * 5.0 + _Time.y * 0.5) * 2.0 - 1.0;
                float noise2 = Noise2D(uv * 3.0 - _Time.y * 0.3) * 2.0 - 1.0;

                uv.x += sin(uv.y * 10.0 + _Time.y) * distortAmount * (1.0 - t);
                uv += float2(noise, noise2) * distortAmount * (1.0 - t) * 0.1;

                return uv;
            }

            // ─────────────────────────────────────────────────────
            // FRAGMENT SHADER
            // ─────────────────────────────────────────────────────

            half4 BlendFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.uv;
                float t = lerp(_BlendAmount, frac(_Time.y * _TransitionSpeed), step(0.5, _UseTime));
                t = lerp(t, 1.0 - t, step(0.5, _InvertTransition));

                // Apply distortion
                float2 uvDistorted = ApplyDistortion(uv, t, _Distortion);

                // Sample textures
                half3 colorA = SAMPLE_TEXTURE2D(_TextureA, sampler_TextureA, uv).rgb;
                half3 colorB = SAMPLE_TEXTURE2D(_TextureB, sampler_TextureB, uvDistorted).rgb;

                // Compute transition mask based on blend mode
                float mask = 0.0;

                int mode = int(_BlendMode);
                if (mode == 0)
                    mask = TransitionLinear(t);
                else if (mode == 1)
                    mask = TransitionDissolve(uv, t);
                else if (mode == 2)
                    mask = TransitionVoronoi(uv, t);
                else if (mode == 3)
                    mask = TransitionRadialSweep(uv, t);
                else if (mode == 4)
                    mask = TransitionAngularSweep(uv, t);
                else if (mode == 5)
                    mask = TransitionStippling(uv, t);
                else if (mode == 6)
                    mask = TransitionWave(uv, t);
                else if (mode == 7)
                    mask = TransitionFractal(uv, t);
                else if (mode == 8)
                    mask = TransitionPixelScatter(uv, t);

                // Blend textures
                half3 result = lerp(colorA, colorB, saturate(mask));

                return half4(result, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
