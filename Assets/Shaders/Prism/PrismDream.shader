Shader "Unlit/PrismDream"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ShapeMode ("Shape Mode", Range(0, 6)) = 0
        _PatternBlend ("Pattern Blend", Range(0, 1)) = 0
        _RepeatScale ("Repeat Scale", Range(0.25, 4)) = 1.15
        _WarpStrength ("Warp Strength", Range(0, 2)) = 0.55
        _PrismRadius ("Shape Radius", Range(0.5, 5)) = 3.5
        _StepScale ("March Step Scale", Range(0.1, 1.5)) = 0.85
        _ColorSpread ("Color Spread", Range(0.1, 4)) = 1.2
        _Exposure ("Exposure", Range(0.1, 5)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "PrismDream"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define CODEX_PI 3.14159265359
            #define CODEX_TWO_PI 6.28318530718

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _ShapeMode;
                float _PatternBlend;
                float _RepeatScale;
                float _WarpStrength;
                float _PrismRadius;
                float _StepScale;
                float _ColorSpread;
                float _Exposure;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            float modeWeight(float mode, float target)
            {
                return saturate(1.0 - abs(mode - target));
            }

            float2 rotate2(float2 p, float a)
            {
                float s = sin(a);
                float c = cos(a);
                return float2(c * p.x - s * p.y, s * p.x + c * p.y);
            }

            float3 repeatCell(float3 p, float cellSize)
            {
                return frac(p / max(cellSize, 0.0001) + 0.5) * cellSize - 0.5 * cellSize;
            }

            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            float sdOctahedron(float3 p, float s)
            {
                p = abs(p);
                return (p.x + p.y + p.z - s) * 0.57735026919;
            }

            float sdTriPrism(float3 p, float2 h)
            {
                float3 q = abs(p);
                return max(q.z - h.y, max(q.x * 0.866025404 + p.y * 0.5, -p.y) - h.x * 0.5);
            }

            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }

            float sdCross(float3 p, float arm, float width)
            {
                float dX = sdBox(p, float3(arm, width, width));
                float dY = sdBox(p, float3(width, arm, width));
                float dZ = sdBox(p, float3(width, width, arm));
                return min(dX, min(dY, dZ));
            }

            float sdStarPrism(float3 p, float radius, float height, float points, float sharpness)
            {
                float angle = atan2(p.y, p.x);
                float radial = length(p.xy);
                float wave = cos(floor(0.5 + angle * points / CODEX_TWO_PI) * CODEX_TWO_PI / points - angle);
                float side = radial * wave - radius;
                float teeth = abs(cos(angle * points)) * sharpness;
                return max(side - teeth, abs(p.z) - height);
            }

            float sceneShape(float3 p)
            {
                float time = _Time.y;
                float radius = max(_PrismRadius, 0.0001);
                float cellSize = max(1.75, radius * 1.2) / max(_RepeatScale, 0.0001);

                p.xz = rotate2(p.xz, time * 0.35);
                p.xy = rotate2(p.xy, 0.2 * sin(time * 0.4) + p.z * 0.025);
                p += _WarpStrength * 0.28 * sin(p.yzx * 1.7 + time * float3(0.31, 0.43, 0.53));

                float3 q = repeatCell(p, cellSize);
                float3 rq = q;
                rq.xy = rotate2(rq.xy, time * 0.2 + floor((p.z + cellSize * 0.5) / cellSize) * 0.75);

                float diamondPrism = abs((max(abs(p.x) + abs(p.y), abs(p.z)) - radius) * 0.57735026919);
                float cubePrism = abs(sdBox(q, float3(cellSize * 0.31, cellSize * 0.31, cellSize * 0.78))) - 0.035;
                float octaCrystal = abs(sdOctahedron(q, cellSize * 0.62)) - 0.045;
                float triPrism = abs(sdTriPrism(rq.xzy, float2(cellSize * 0.82, cellSize * 0.34))) - 0.035;
                float starColumn = abs(sdStarPrism(rq, cellSize * 0.23, cellSize * 0.5, 5.0, cellSize * 0.055)) - 0.035;
                float ringPrism = abs(sdTorus(float3(q.x, q.y, q.z + 0.15 * sin(time + p.x)), float2(cellSize * 0.28, cellSize * 0.07))) - 0.025;
                float crossLattice = abs(sdCross(q, cellSize * 0.48, cellSize * 0.095)) - 0.03;

                float mode = clamp(_ShapeMode, 0.0, 6.0);
                float selected = diamondPrism * modeWeight(mode, 0.0)
                               + cubePrism * modeWeight(mode, 1.0)
                               + octaCrystal * modeWeight(mode, 2.0)
                               + triPrism * modeWeight(mode, 3.0)
                               + starColumn * modeWeight(mode, 4.0)
                               + ringPrism * modeWeight(mode, 5.0)
                               + crossLattice * modeWeight(mode, 6.0);

                float hybrid = min(min(diamondPrism, cubePrism), min(min(octaCrystal, triPrism), min(starColumn, min(ringPrism, crossLattice))));
                return lerp(selected, hybrid, _PatternBlend);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float z = 5.0;
                float dist = 1.0;
                float3 p = 0.0;
                float4 col = 0.0;
                float2 coord = (IN.positionCS.xy - 0.5 * _ScreenParams.xy) / _ScreenParams.y / 0.1;

                [loop]
                for (int i = 0; i < 100; i++)
                {
                    p = float3(coord, z);
                    p.xz = rotate2(p.xz, _Time.y + 0.5);

                    dist = 0.08 + _StepScale * 0.22 * sceneShape(p);
                    dist = max(abs(dist), 0.002);

                    float4 spectral = sin((p.y + z) * _ColorSpread + float4(0.0, 1.6, 3.2, 4.8)) + 1.0;
                    float pulse = 0.7 + 0.3 * cos(length(p.xy) * 0.45 - _Time.y * 1.6);
                    col += spectral * pulse / dist;

                    z -= dist;
                }

                col = tanh(col * col * _Exposure / 100000.0);
                return half4(col.rgb, 1.0);
            }
            ENDHLSL
        }
    }
}
