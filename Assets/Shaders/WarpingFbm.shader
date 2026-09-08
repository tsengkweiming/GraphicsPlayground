Shader "Unlit/WarpingFbm"
{
    Properties
    {
        // Faithful conversion of:
        // https://www.shadertoy.com/view/lsl3RH
        _MainTex ("Texture", 2D) = "white" {}
        _Size ("Size", Float) = 1
        _PatternScale ("Pattern Scale", Range(0.1, 4)) = 1
        _Offset ("Canvas Offset (XY)", Vector) = (0, 0, 0, 0)
        _CanvasAspect ("Canvas Aspect (W/H)", Float) = 1
        _TimeScale ("Animation Speed", Float) = 1
        _WarpStrength ("Radial Warp Strength", Range(0, 0.2)) = 0.03
        _WarpFrequency ("Radial Warp Frequency (XY)", Vector) = (4.1, 4.3, 0, 0)
        _WarpSpeed ("Radial Warp Speed (XY)", Vector) = (0.27, 0.23, 0, 0)
        _DomainWarpStrength ("Domain Warp Strength", Range(0, 0.2)) = 0.04
        _DomainWarpScale ("Domain Warp Scale", Range(0, 8)) = 3
        _DetailStrength ("FBM Detail Strength", Range(0, 2)) = 1
        _ColorA ("Palette A", Color) = (0.2, 0.1, 0.4, 1)
        _ColorB ("Palette B", Color) = (0.3, 0.05, 0.05, 1)
        _ColorC ("Palette C", Color) = (0.9, 0.9, 0.9, 1)
        _ColorD ("Palette D", Color) = (0, 0.2, 0.4, 1)
        _ColorContrast ("Color Contrast", Range(0, 2)) = 1
        _ColorBrightness ("Color Brightness", Range(0, 3)) = 1
        _RimStrength ("Rim Highlight Strength", Range(0, 2)) = 1
        _LightDirection ("Light Direction", Vector) = (0.9, 0.2, -0.4, 0)
        _AmbientColor ("Ambient Color", Color) = (0.7, 0.9, 0.95, 1)
        _LightColor ("Light Color", Color) = (0.15, 0.1, 0.05, 1)
        _LightStrength ("Light Strength", Range(0, 3)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "WarpingFbm"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Offset;
                float _Size;
                float _PatternScale;
                float _CanvasAspect;
                float _TimeScale;
                float _WarpStrength;
                float4 _WarpFrequency;
                float4 _WarpSpeed;
                float _DomainWarpStrength;
                float _DomainWarpScale;
                float _DetailStrength;
                float4 _ColorA;
                float4 _ColorB;
                float4 _ColorC;
                float4 _ColorD;
                float _ColorContrast;
                float _ColorBrightness;
                float _RimStrength;
                float4 _LightDirection;
                float4 _AmbientColor;
                float4 _LightColor;
                float _LightStrength;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // GLSL:
            // const mat2 m = mat2(0.80, 0.60, -0.60, 0.80);
            // GLSL mat2 constructors are column-major, so this is the equivalent
            // HLSL vector multiplication.
            float2 RotateFbm(float2 p)
            {
                return float2(0.80 * p.x - 0.60 * p.y,
                    0.60 * p.x + 0.80 * p.y);
            }

            float Noise(float2 p)
            {
                return sin(p.x) * sin(p.y);
            }

            float Fbm4(float2 p)
            {
                float f = 0.0;
                f += 0.5000 * Noise(p);
                p = RotateFbm(p) * 2.02;
                f += 0.2500 * Noise(p);
                p = RotateFbm(p) * 2.03;
                f += 0.1250 * Noise(p);
                p = RotateFbm(p) * 2.01;
                f += 0.0625 * Noise(p);
                return f / 0.9375;
            }

            float Fbm6(float2 p)
            {
                float f = 0.0;
                f += 0.500000 * (0.5 + 0.5 * Noise(p));
                p = RotateFbm(p) * 2.02;
                f += 0.250000 * (0.5 + 0.5 * Noise(p));
                p = RotateFbm(p) * 2.03;
                f += 0.125000 * (0.5 + 0.5 * Noise(p));
                p = RotateFbm(p) * 2.01;
                f += 0.062500 * (0.5 + 0.5 * Noise(p));
                p = RotateFbm(p) * 2.04;
                f += 0.031250 * (0.5 + 0.5 * Noise(p));
                p = RotateFbm(p) * 2.01;
                f += 0.015625 * (0.5 + 0.5 * Noise(p));
                return f / 0.96875;
            }

            float2 Fbm4_2(float2 p)
            {
                return float2(Fbm4(p), Fbm4(p + float2(7.8, 7.8)));
            }

            float2 Fbm6_2(float2 p)
            {
                return float2(Fbm6(p + float2(16.8, 16.8)),
                    Fbm6(p + float2(11.5, 11.5)));
            }

            // Equivalent to:
            // float func(vec2 q, out vec4 ron)
            float WarpedField(float2 q, float time, out float4 ron)
            {
                q += _WarpStrength * sin(_WarpSpeed.xy * time +
                    length(q) * _WarpFrequency.xy);

                float2 o = Fbm4_2(0.9 * q);
                o += _DomainWarpStrength * sin(float2(0.12, 0.14) * time +
                    length(o));

                float2 n = Fbm6_2(_DomainWarpScale * o) * _DetailStrength;
                ron = float4(o, n);

                float f = 0.5 + 0.5 * Fbm4(1.8 * q + 6.0 * n);
                return lerp(f, f * f * f * 3.5, f * abs(n.x));
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float safeSize = max(abs(_Size), 0.0001);
                float safeAspect = max(abs(_CanvasAspect), 0.0001);

                // Shadertoy:
                // vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
                float2 p = (input.uv * 2.0 - 1.0) * float2(safeAspect, 1.0);
                p = p / safeSize * _PatternScale + _Offset.xy;

                float time = _Time.y * _TimeScale;
                float epsilon = 2.0 / max(_ScreenParams.y * safeSize, 1.0);

                float4 on;
                float f = WarpedField(p, time, on);

                float3 color = lerp(_ColorA.rgb, _ColorB.rgb, f);
                color = lerp(color, _ColorC.rgb,
                    saturate(_RimStrength * dot(on.zw, on.zw)));
                color = lerp(color, float3(0.4, 0.3, 0.3),
                    0.2 + 0.5 * on.y * on.y);
                color = lerp(color, _ColorD.rgb,
                    0.5 * smoothstep(1.2, 1.3, abs(on.z) + abs(on.w)));
                color = saturate(color * f * 2.0 * _ColorBrightness);
                color = lerp(float3(0.5, 0.5, 0.5), color,
                    _ColorContrast);

                // The original uses manual derivatives for better quality.
                float4 derivativeData;
                float fieldX = WarpedField(p + float2(epsilon, 0.0), time, derivativeData) - f;
                float fieldY = WarpedField(p + float2(0.0, epsilon), time, derivativeData) - f;
                float3 normal = normalize(float3(fieldX, 2.0 * epsilon, fieldY) + 1e-6);

                float3 lightDirection = normalize(_LightDirection.xyz);
                float diffuse = saturate(0.3 + 0.7 * dot(normal, lightDirection));
                float3 lighting = _AmbientColor.rgb * (normal.y * 0.5 + 0.5)
                    + _LightColor.rgb * diffuse;
                color *= 1.2 * lighting * _LightStrength;

                color = 1.0 - color;
                color = 1.1 * color * color;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
