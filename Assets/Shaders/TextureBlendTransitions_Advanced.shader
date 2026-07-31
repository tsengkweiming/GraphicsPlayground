Shader "Hidden/Texture Blend Transitions (Advanced - SDF Based)"
{
    Properties
    {
        _TextureA ("Texture A", 2D) = "white" {}
        _TextureB ("Texture B", 2D) = "white" {}

        _TransitionMode ("Transition Mode", Range(0, 5)) = 0
        _BlendAmount ("Blend Amount (0-1)", Range(0, 1)) = 0.5
        _TransitionSpeed ("Transition Speed", Range(0.1, 5)) = 1.0

        // SDF Parameters
        _SDFScale ("SDF Scale (Complexity)", Range(1, 20)) = 4.0
        _SDFThickness ("SDF Line Thickness", Range(0.01, 0.2)) = 0.05
        _SDFSmoothing ("SDF Edge Smoothing", Range(0.001, 0.1)) = 0.02

        // Distortion
        _WaveAmplitude ("Wave Amplitude", Range(0, 1)) = 0.1
        _WaveFrequency ("Wave Frequency", Range(0.5, 10)) = 2.0

        [Toggle] _UseTime ("Use Time Auto", Float) = 1
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
            Name "TextureBlendAdvanced"
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
                float _TransitionMode;
                float _BlendAmount;
                float _TransitionSpeed;
                float _SDFScale;
                float _SDFThickness;
                float _SDFSmoothing;
                float _WaveAmplitude;
                float _WaveFrequency;
                float _UseTime;
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
            // MATH UTILITIES
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

            // ─────────────────────────────────────────────────────
            // SDF OPERATIONS (Signed Distance Fields)
            // ─────────────────────────────────────────────────────

            // SDF: Circle
            float SDFCircle(float2 p, float r)
            {
                return length(p) - r;
            }

            // SDF: Box
            float SDFBox(float2 p, float2 b)
            {
                float2 d = abs(p) - b;
                return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
            }

            // SDF: Line segment
            float SDFLineSegment(float2 p, float2 a, float2 b)
            {
                float2 pa = p - a;
                float2 ba = b - a;
                float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
                return length(pa - ba * h);
            }

            // SDF: Hexagon
            float SDFHexagon(float2 p, float r)
            {
                const float3 k = float3(-0.866025, 0.5, 0.577350);
                p = abs(p);
                p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
                p -= float2(clamp(p.x, -k.z * r, k.z * r), r);
                return length(p) * sign(p.y);
            }

            // SDF: Triangle
            float SDFTriangle(float2 p, float2 a, float2 b, float2 c)
            {
                float d1 = SDFLineSegment(p, a, b);
                float d2 = SDFLineSegment(p, b, c);
                float d3 = SDFLineSegment(p, c, a);
                return min(min(d1, d2), d3);
            }

            // ─────────────────────────────────────────────────────
            // SDF TRANSITION MASKS
            // ─────────────────────────────────────────────────────

            // 0: SDF Circle expansion
            float TransitionSDFCircle(float2 uv, float t)
            {
                float2 p = (uv - 0.5) * 2.0;
                float d = SDFCircle(p, t + 0.5);
                return smoothstep(-_SDFSmoothing, _SDFSmoothing, -d);
            }

            // 1: SDF Hexagon wave
            float TransitionSDFHexagon(float2 uv, float t)
            {
                float2 p = (uv - 0.5) * 2.0;
                float d = SDFHexagon(p, 0.3 + t * 0.5);
                float wave = sin(atan2(p.y, p.x) * 6.0 + _Time.y) * 0.1;
                d += wave;
                return smoothstep(-_SDFSmoothing, _SDFSmoothing, -d);
            }

            // 2: SDF Multi-box rotation
            float TransitionSDFBoxes(float2 uv, float t)
            {
                float2 p = (uv - 0.5) * 2.0;

                // Rotate
                float angle = t * 3.14159;
                float c = cos(angle);
                float s = sin(angle);
                p = float2(p.x * c - p.y * s, p.x * s + p.y * c);

                float d = SDFBox(p, float2(0.2 + t * 0.3, 0.2 + t * 0.3));
                return smoothstep(-_SDFSmoothing, _SDFSmoothing, -d);
            }

            // 3: SDF Mandelbrot-like fractal boundary
            float TransitionSDFFractalBoundary(float2 uv, float t)
            {
                float2 p = (uv - 0.5) * 3.0;
                float angle = atan2(p.y, p.x);
                float radius = length(p);

                // Pseudo-fractal condition
                float fractal = sin(angle * _SDFScale + _Time.y * 0.5);
                fractal += sin(radius * _SDFScale - t * 3.14159);
                fractal = frac(fractal);

                return smoothstep(t - 0.2, t + 0.2, fractal);
            }

            // 4: SDF Interference pattern (moiré)
            float TransitionSDFMoire(float2 uv, float t)
            {
                float2 p = uv * _SDFScale;
                float wave1 = sin(p.x * 3.14159 + t * 3.14159);
                float wave2 = sin(p.y * 3.14159 - t * 3.14159);
                float moire = wave1 * wave2;
                return smoothstep(-0.1, 0.1, moire + sin(t * 3.14159) * 0.5);
            }

            // 5: SDF Recursive tessellation
            float TransitionSDFTessellation(float2 uv, float t)
            {
                float2 p = frac(uv * _SDFScale) - 0.5;
                float d = length(p);

                // Multiple scales
                float mask1 = smoothstep(0.3 - t * 0.3, 0.3, d);
                float mask2 = smoothstep(0.15 - t * 0.15, 0.15, d);

                return max(mask1, mask2);
            }

            // ─────────────────────────────────────────────────────
            // WAVE DISTORTION
            // ─────────────────────────────────────────────────────

            float2 ApplyWaveDistortion(float2 uv, float t)
            {
                float wave = sin(uv.x * _WaveFrequency * 3.14159 + _Time.y) * _WaveAmplitude;
                wave += sin(uv.y * _WaveFrequency * 1.5 - _Time.y * 0.5) * _WaveAmplitude * 0.5;

                uv.x += wave * (1.0 - t);
                uv.y += cos(uv.x * _WaveFrequency + _Time.y) * _WaveAmplitude * 0.3 * (1.0 - t);

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

                // Apply wave distortion
                float2 uvDistorted = ApplyWaveDistortion(uv, t);

                // Sample textures
                half3 colorA = SAMPLE_TEXTURE2D(_TextureA, sampler_TextureA, uv).rgb;
                half3 colorB = SAMPLE_TEXTURE2D(_TextureB, sampler_TextureB, uvDistorted).rgb;

                // Compute SDF-based transition mask
                float mask = 0.0;

                int mode = int(_TransitionMode);
                if (mode == 0)
                    mask = TransitionSDFCircle(uv, t);
                else if (mode == 1)
                    mask = TransitionSDFHexagon(uv, t);
                else if (mode == 2)
                    mask = TransitionSDFBoxes(uv, t);
                else if (mode == 3)
                    mask = TransitionSDFFractalBoundary(uv, t);
                else if (mode == 4)
                    mask = TransitionSDFMoire(uv, t);
                else if (mode == 5)
                    mask = TransitionSDFTessellation(uv, t);

                // Blend with smooth transitions
                half3 result = lerp(colorA, colorB, saturate(mask));

                return half4(result, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
