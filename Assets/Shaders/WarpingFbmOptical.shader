Shader "Unlit/WarpingFbmOptical"
{
    Properties
    {
        // FBM source: https://www.shadertoy.com/view/lsl3RH
        _MainTex ("Texture", 2D) = "white" {}
        _Size ("Size", Float) = 1
        _Offset ("Canvas Offset (XY)", Vector) = (0, 0, 0, 0)
        _CanvasAspect ("Canvas Aspect (W/H)", Float) = 1
        _TimeScale ("Animation Speed", Float) = 1
        _IOR ("Index of Refraction", Range(1.01, 2.5)) = 1.45
        _Roughness ("Optical Roughness", Range(0, 0.25)) = 0.02
        _Absorption ("Beer-Lambert Absorption", Range(0, 4)) = 0.35
        _Bounces ("Path Bounces", Range(1, 4)) = 3
        _Samples ("Path Samples", Range(1, 4)) = 2
        _SurfaceTint ("Surface Tint", Color) = (0.72, 0.88, 1.0, 1.0)
        _Exposure ("Exposure", Range(0.1, 4)) = 1
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
            Name "WarpingFbmOptical"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define CODEX_MAX_BOUNCES 4
            #define CODEX_MAX_SAMPLES 4
            #define CODEX_RAY_STEPS 48
            #define CODEX_BOUND_RADIUS 1.45
            #define CODEX_SURFACE_EPSILON 0.002

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
                float4 _SurfaceTint;
                float _Size;
                float _CanvasAspect;
                float _TimeScale;
                float _IOR;
                float _Roughness;
                float _Absorption;
                float _Bounces;
                float _Samples;
                float _Exposure;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // The original Shadertoy rotation:
            // mat2(0.80, 0.60, -0.60, 0.80), interpreted column-major.
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

            float WarpedField(float2 q, float time, out float4 coordinates)
            {
                q += 0.03 * sin(float2(0.27, 0.23) * time +
                    length(q) * float2(4.1, 4.3));

                float2 o = Fbm4_2(0.9 * q);
                o += 0.04 * sin(float2(0.12, 0.14) * time + length(o));

                float2 n = Fbm6_2(3.0 * o);
                coordinates = float4(o, n);

                float f = 0.5 + 0.5 * Fbm4(1.8 * q + 6.0 * n);
                return lerp(f, f * f * f * 3.5, f * abs(n.x));
            }

            // A closed FBM-displaced optical object. The displacement is bounded
            // to keep the analytic sphere intersection conservative.
            float SurfaceField(float3 p, float time, out float fieldValue)
            {
                float4 coordinates;
                float warped = WarpedField(
                    p.xz * 1.55 + p.y * float2(0.37, -0.22),
                    time,
                    coordinates);
                float displacement = (saturate(warped) - 0.5) * 0.24;
                fieldValue = saturate(0.5 + 0.5 * coordinates.z + 0.25 * coordinates.w);
                return length(p) - (1.08 + displacement);
            }

            float3 SurfaceNormal(float3 p, float time)
            {
                float epsilon = 0.003;
                float ignored;
                float dx = SurfaceField(p + float3(epsilon, 0.0, 0.0), time, ignored)
                    - SurfaceField(p - float3(epsilon, 0.0, 0.0), time, ignored);
                float dy = SurfaceField(p + float3(0.0, epsilon, 0.0), time, ignored)
                    - SurfaceField(p - float3(0.0, epsilon, 0.0), time, ignored);
                float dz = SurfaceField(p + float3(0.0, 0.0, epsilon), time, ignored)
                    - SurfaceField(p - float3(0.0, 0.0, epsilon), time, ignored);
                return normalize(float3(dx, dy, dz) + 1e-6);
            }

            float RaySphereNear(float3 rayOrigin, float3 rayDirection,
                float radius, out float farDistance)
            {
                float b = dot(rayOrigin, rayDirection);
                float c = dot(rayOrigin, rayOrigin) - radius * radius;
                float discriminant = b * b - c;
                farDistance = 0.0;
                if (discriminant < 0.0)
                    return -1.0;

                float root = sqrt(discriminant);
                farDistance = -b + root;
                return -b - root;
            }

            float TraceSurface(float3 rayOrigin, float3 rayDirection, float time,
                out float travel, out float fieldValue)
            {
                float farDistance;
                float nearDistance = RaySphereNear(
                    rayOrigin,
                    rayDirection,
                    CODEX_BOUND_RADIUS,
                    farDistance);
                travel = max(nearDistance, 0.0);
                fieldValue = 0.0;

                if (nearDistance < 0.0 && farDistance <= 0.0)
                    return 0.0;

                float3 position = rayOrigin + rayDirection * travel;
                float hit = 0.0;

                [loop]
                for (int stepIndex = 0; stepIndex < CODEX_RAY_STEPS; ++stepIndex)
                {
                    float distanceField = SurfaceField(position, time, fieldValue);
                    float distanceToSurface = abs(distanceField);
                    hit = 1.0 - step(CODEX_SURFACE_EPSILON, distanceToSurface);
                    if (hit > 0.5)
                        break;

                    float stepDistance = clamp(distanceToSurface, 0.004, 0.12);
                    travel += stepDistance;
                    if (travel > farDistance)
                    {
                        hit = 0.0;
                        break;
                    }
                    position += rayDirection * stepDistance;
                }

                return hit;
            }

            // Exact unpolarized dielectric Fresnel equations.
            float DielectricFresnel(float cosIncident,
                float etaIncident,
                float etaTransmitted)
            {
                float eta = etaIncident / max(etaTransmitted, 0.0001);
                float sinTransmittedSquared = eta * eta *
                    (1.0 - cosIncident * cosIncident);
                if (sinTransmittedSquared >= 1.0)
                    return 1.0;

                float cosTransmitted = sqrt(max(1.0 - sinTransmittedSquared, 0.0));
                float rs = (etaIncident * cosIncident - etaTransmitted * cosTransmitted)
                    / max(etaIncident * cosIncident + etaTransmitted * cosTransmitted, 0.0001);
                float rp = (etaTransmitted * cosIncident - etaIncident * cosTransmitted)
                    / max(etaTransmitted * cosIncident + etaIncident * cosTransmitted, 0.0001);
                return saturate(0.5 * (rs * rs + rp * rp));
            }

            float Hash12(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float Hash13(float3 p)
            {
                return frac(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453);
            }

            float3 Environment(float3 rayDirection, float time)
            {
                float horizon = saturate(rayDirection.y * 0.5 + 0.5);
                float3 sky = lerp(float3(0.015, 0.025, 0.06),
                    float3(0.24, 0.48, 0.85),
                    horizon);
                float cloud = saturate(0.5 + 0.5 *
                    Fbm4(rayDirection.xz * 2.4 + time * 0.035));
                sky += cloud * float3(0.07, 0.11, 0.16) *
                    saturate(rayDirection.y);

                float sun = pow(saturate(dot(rayDirection,
                    normalize(float3(-0.35, 0.45, -0.8)))), 96.0);
                return sky + sun * float3(5.0, 3.6, 2.2);
            }

            float3 TracePath(float3 rayOrigin, float3 rayDirection,
                float time, float randomSeed)
            {
                float3 radiance = 0.0;
                float3 throughput = 1.0;
                bool inside = false;

                [loop]
                for (int bounceIndex = 0;
                    bounceIndex < CODEX_MAX_BOUNCES;
                    ++bounceIndex)
                {
                    if (bounceIndex >= _Bounces)
                        break;

                    float travel;
                    float fieldValue;
                    float hit = TraceSurface(
                        rayOrigin,
                        rayDirection,
                        time,
                        travel,
                        fieldValue);
                    if (hit < 0.5)
                    {
                        radiance += throughput * Environment(rayDirection, time);
                        break;
                    }

                    float3 position = rayOrigin + rayDirection * travel;
                    float3 normal = SurfaceNormal(position, time);
                    float3 faceNormal = inside ? -normal : normal;
                    float cosIncident = saturate(dot(-rayDirection, faceNormal));
                    float etaIncident = inside ? _IOR : 1.0;
                    float etaTransmitted = inside ? 1.0 : _IOR;
                    float fresnel = DielectricFresnel(
                        cosIncident,
                        etaIncident,
                        etaTransmitted);
                    float3 refractedDirection = refract(
                        rayDirection,
                        faceNormal,
                        etaIncident / max(etaTransmitted, 0.0001));
                    float totalInternalReflection = step(0.999, fresnel);

                    float surfaceVariation = saturate(0.65 + 0.35 * fieldValue);
                    throughput *= lerp(1.0, _SurfaceTint.rgb,
                        0.16 * surfaceVariation);
                    throughput *= inside
                        ? exp(-_Absorption * travel * 0.18)
                        : 1.0;

                    float randomChoice = Hash13(float3(
                        position.xy,
                        randomSeed + bounceIndex * 17.0));
                    bool reflectPath = randomChoice < fresnel ||
                        totalInternalReflection > 0.5;
                    if (reflectPath)
                    {
                        rayDirection = reflect(rayDirection, faceNormal);
                    }
                    else
                    {
                        rayDirection = normalize(refractedDirection);
                        inside = !inside;
                    }

                    float roughness = _Roughness * (1.0 - fresnel);
                    float3 tangentNoise = float3(
                        Hash12(position.xy + randomSeed) - 0.5,
                        Hash12(position.zy + randomSeed * 1.7) - 0.5,
                        Hash12(position.xz + randomSeed * 2.3) - 0.5);
                    rayDirection = normalize(lerp(
                        rayDirection,
                        normalize(rayDirection + tangentNoise),
                        roughness));
                    rayOrigin = position +
                        (inside ? -faceNormal : faceNormal) * 0.006;
                    throughput *= 0.985;
                }

                return radiance;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float safeSize = max(abs(_Size), 0.0001);
                float safeAspect = max(abs(_CanvasAspect), 0.0001);
                float2 uv = (input.uv * 2.0 - 1.0) *
                    float2(safeAspect, 1.0);
                uv = uv / safeSize + _Offset.xy;

                float time = _Time.y * _TimeScale;
                float3 rayOrigin = float3(0.0, 0.0, -3.8);
                float3 rayDirection = normalize(float3(uv.x, uv.y, 2.7));
                float3 color = 0.0;

                [loop]
                for (int sampleIndex = 0;
                    sampleIndex < CODEX_MAX_SAMPLES;
                    ++sampleIndex)
                {
                    if (sampleIndex >= _Samples)
                        break;

                    float2 pixel = input.uv * _ScreenParams.xy;
                    float sampleSeed = Hash12(pixel + sampleIndex * 19.19);
                    float2 jitter = (float2(
                        Hash12(pixel + sampleIndex * 3.1),
                        Hash12(pixel + sampleIndex * 7.7)) - 0.5) * 0.0015;
                    float3 sampleDirection = normalize(float3(
                        uv + jitter,
                        2.7));
                    color += TracePath(
                        rayOrigin,
                        sampleDirection,
                        time,
                        sampleSeed);
                }
                color /= max(_Samples, 1.0);

                color = 1.0 - exp(-color * _Exposure);
                color = pow(max(color, 0.0), 1.0 / 2.2);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
