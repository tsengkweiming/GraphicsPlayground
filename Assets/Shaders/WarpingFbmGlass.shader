Shader "Unlit/WarpingFbmGlass"
{
    Properties
    {
        // Flat glass optical conversion based on:
        // https://www.shadertoy.com/view/lsl3RH
        _MainTex ("Image Behind Glass", 2D) = "white" {}
        [Toggle] _UseProceduralFbm ("Use Procedural lsl3RH FBM", Float) = 1
        _Size ("Size", Float) = 1
        _Offset ("Canvas Offset (XY)", Vector) = (0, 0, 0, 0)
        _CanvasAspect ("Canvas Aspect (W/H)", Float) = 1
        _TimeScale ("Animation Speed", Float) = 1
        _CameraPos ("Virtual Camera Position", Vector) = (0, 0, 2.5, 0)
        _CameraTarget ("Virtual Camera Target", Vector) = (0, 0, 0, 0)
        _CameraFov ("Virtual Camera FOV", Range(10, 120)) = 45
        _GlassPosition ("Glass Z Position", Float) = 1
        _GlassThickness ("Glass Thickness", Range(0, 1)) = 0.03
        _IOR ("Index of Refraction", Range(1.01, 2.5)) = 1.45
        _Aberration ("Chromatic Aberration", Range(0, 1)) = 0.15
        _NoiseScale ("Glass FBM Scale", Range(0.01, 10)) = 1
        _NoiseStrength ("Glass Bump Strength", Range(0, 2)) = 0.35
        _NoiseType ("Glass Noise Type", Range(0, 2)) = 0
        _NoiseSmoothness ("Glass Noise Smoothness", Range(0, 1)) = 0.4
        _GlassRoughness ("Glass Roughness", Range(0, 0.25)) = 0
        _Samples ("Path Samples", Range(1, 4)) = 1
        _Absorption ("Beer-Lambert Absorption", Range(0, 4)) = 0
        _GlassTint ("Glass Tint", Color) = (1, 1, 1, 1)
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
            Name "WarpingFbmGlass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_BOUNCES 1
            #define MAX_SAMPLES 1
            #define PI 3.14159265359

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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Offset;
                float4 _CameraPos;
                float4 _CameraTarget;
                float _UseProceduralFbm;
                float _Size;
                float _CanvasAspect;
                float _TimeScale;
                float _CameraFov;
                float _GlassPosition;
                float _GlassThickness;
                float _IOR;
                float _Aberration;
                float _NoiseScale;
                float _NoiseStrength;
                float _NoiseType;
                float _NoiseSmoothness;
                float _GlassRoughness;
                float _Samples;
                float _Absorption;
                float4 _GlassTint;
                float _Exposure;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // lsl3RH's mat2(0.80, 0.60, -0.60, 0.80), converted from GLSL
            // column-major construction to an explicit HLSL operation.
            float2 RotateFbm(float2 p)
            {
                return float2(0.80 * p.x - 0.60 * p.y,
                    0.60 * p.x + 0.80 * p.y);
            }

            float Noise(float2 p)
            {
                return sin(p.x) * sin(p.y);
            }

            float HashNoise(float2 p)
            {
                float3 p3 = frac(float3(p.x, p.y, p.x) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            float ValueNoise(float2 p)
            {
                float2 cell = floor(p);
                float2 local = frac(p);
                local = local * local * (3.0 - 2.0 * local);
                float a = HashNoise(cell);
                float b = HashNoise(cell + float2(1.0, 0.0));
                float c = HashNoise(cell + float2(0.0, 1.0));
                float d = HashNoise(cell + float2(1.0, 1.0));
                return lerp(lerp(a, b, local.x), lerp(c, d, local.x), local.y);
            }

            float3 Mod289(float3 x)
            {
                return x - floor(x * (1.0 / 289.0)) * 289.0;
            }

            float2 Mod289(float2 x)
            {
                return x - floor(x * (1.0 / 289.0)) * 289.0;
            }

            float3 Permute(float3 x)
            {
                return Mod289(((x * 34.0) + 10.0) * x);
            }

            float SimplexNoise(float2 v)
            {
                const float4 c = float4(
                    0.211324865405187,
                    0.366025403784439,
                    -0.577350269189626,
                    0.024390243902439);
                float2 cell = floor(v + dot(v, c.yy));
                float2 x0 = v - cell + dot(cell, c.xx);
                float2 i1 = x0.x > x0.y
                    ? float2(1.0, 0.0)
                    : float2(0.0, 1.0);
                float4 x12 = x0.xyxy + c.xxzz;
                x12.xy -= i1;
                cell = Mod289(cell);
                float3 p = Permute(Permute(cell.y + float3(0.0, i1.y, 1.0))
                    + cell.x + float3(0.0, i1.x, 1.0));
                float3 m = max(0.5 - float3(
                    dot(x0, x0),
                    dot(x12.xy, x12.xy),
                    dot(x12.zw, x12.zw)), 0.0);
                m *= m;
                m *= m;
                float3 x = 2.0 * frac(p * c.www) - 1.0;
                float3 h = abs(x) - 0.5;
                float3 ox = floor(x + 0.5);
                float3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 *
                    (a0 * a0 + h * h);
                float3 g;
                g.x = a0.x * x0.x + h.x * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            float WorleyNoise(float2 p)
            {
                float2 cell = floor(p);
                float2 local = frac(p);
                float minimumDistance = 1.0;

                [unroll]
                for (int y = -1; y <= 1; ++y)
                {
                    [unroll]
                    for (int x = -1; x <= 1; ++x)
                    {
                        float2 neighbor = float2((float)x, (float)y);
                        float2 pt = float2(
                            HashNoise(cell + neighbor),
                            HashNoise(cell + neighbor + float2(127.1, 311.7)));
                        float2 difference = neighbor + pt - local;
                        minimumDistance = min(minimumDistance, length(difference));
                    }
                }
                return minimumDistance;
            }

            float GlassFbm(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                float octaveCount = clamp(6.0 - _NoiseSmoothness * 5.0, 1.0, 6.0);
                int noiseType = (int)clamp(_NoiseType, 0.0, 2.0);

                [unroll]
                for (int octave = 0; octave < 6; ++octave)
                {
                    float active = step((float)octave, octaveCount - 0.5);
                    float sample;
                    if (noiseType == 0)
                        sample = ValueNoise(p * frequency);
                    else if (noiseType == 1)
                        sample = SimplexNoise(p * frequency) * 0.5 + 0.5;
                    else
                        sample = WorleyNoise(p * frequency);

                    value += active * amplitude * sample;
                    frequency *= 2.0;
                    amplitude *= lerp(0.3, 0.7, _NoiseSmoothness);
                }
                return value;
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

            float3 ProceduralImage(float2 uv, float time)
            {
                float2 p = (uv * 2.0 - 1.0) * float2(max(_CanvasAspect, 0.0001), 1.0);
                float4 on;
                float f = WarpedField(p, time, on);

                float3 color = lerp(float3(0.2, 0.1, 0.4),
                    float3(0.3, 0.05, 0.05), f);
                color = lerp(color, float3(0.9, 0.9, 0.9), dot(on.zw, on.zw));
                color = lerp(color, float3(0.4, 0.3, 0.3), 0.2 + 0.5 * on.y * on.y);
                color = lerp(color, float3(0.0, 0.2, 0.4),
                    0.5 * smoothstep(1.2, 1.3, abs(on.z) + abs(on.w)));
                color = saturate(color * f * 2.0);
                return color;
            }

            float3 SampleImage(float2 uv, float time)
            {
                float2 wrappedUv = frac(uv);
                float3 imageColor = SAMPLE_TEXTURE2D(
                    _MainTex,
                    sampler_MainTex,
                    wrappedUv).rgb;
                float3 proceduralColor = ProceduralImage(wrappedUv, time);
                return lerp(imageColor, proceduralColor, saturate(_UseProceduralFbm));
            }

            float GlassHeight(float2 position, float time)
            {
                // The pasted flat-glass shader uses u_noiseScale * 10 for its
                // normal field. Keep that scale convention and let the noise
                // selector control the glass surface independently of the
                // procedural lsl3RH image behind it.
                float scale = max(_NoiseScale, 0.0001) * 10.0;
                return GlassFbm(position * scale);
            }

            float3 GlassNormal(float2 position, float3 baseNormal, float time)
            {
                float strength = saturate(_NoiseStrength);
                if (strength < 0.001)
                    return baseNormal;

                float epsilon = 0.01;
                float height = GlassHeight(position, time);
                float heightX = GlassHeight(position + float2(epsilon, 0.0), time);
                float heightY = GlassHeight(position + float2(0.0, epsilon), time);
                float dx = (heightX - height) / epsilon;
                float dy = (heightY - height) / epsilon;
                float3 perturbation = float3(-dx, -dy, 0.0) * strength * 0.3;
                return normalize(baseNormal + perturbation);
            }

            float FresnelDielectric(float cosIncident,
                float etaIncident,
                float etaTransmitted)
            {
                float eta = etaIncident / max(etaTransmitted, 0.0001);
                float sinTransmittedSquared = eta * eta *
                    (1.0 - cosIncident * cosIncident);
                if (sinTransmittedSquared >= 1.0)
                    return 1.0;

                float cosTransmitted = sqrt(max(1.0 - sinTransmittedSquared, 0.0));
                float rs = (etaIncident * cosIncident -
                    etaTransmitted * cosTransmitted) /
                    max(etaIncident * cosIncident +
                        etaTransmitted * cosTransmitted, 0.0001);
                float rp = (etaTransmitted * cosIncident -
                    etaIncident * cosTransmitted) /
                    max(etaTransmitted * cosIncident +
                        etaIncident * cosTransmitted, 0.0001);
                return saturate(0.5 * (rs * rs + rp * rp));
            }

            float Hash12(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float3 PerturbDirection(float3 direction, float2 position, float seed)
            {
                float2 random = float2(
                    Hash12(position.xy + seed),
                    Hash12(position.yx + seed * 1.73)) - 0.5;
                float3 tangentNoise = float3(random, Hash12(position + seed * 2.37) - 0.5);
                return normalize(lerp(direction,
                    normalize(direction + tangentNoise),
                    saturate(_GlassRoughness)));
            }

            float3 TraceRay(float3 rayOrigin, float3 rayDirection,
                float iorOffset, float time, float randomSeed)
            {
                float glassZ = _GlassPosition;
                float glassIor = max(_IOR + iorOffset, 1.001);
                float3 throughput = 1.0;
                bool inside = false;

                [loop]
                for (int bounce = 0; bounce < MAX_BOUNCES; ++bounce)
                {
                    float safeRayZ = abs(rayDirection.z) < 0.0001
                        ? (rayDirection.z < 0.0 ? -0.0001 : 0.0001)
                        : rayDirection.z;
                    float tGlass = (glassZ - rayOrigin.z) / safeRayZ;
                    float tImage = (0.0 - rayOrigin.z) / safeRayZ;
                    float tHit = 1e10;
                    int hitType = -1;

                    if (tGlass > 0.001 && tGlass < tHit)
                    {
                        tHit = tGlass;
                        hitType = 0;
                    }
                    if (tImage > 0.001 && tImage < tHit)
                    {
                        tHit = tImage;
                        hitType = 1;
                    }

                    if (hitType < 0)
                        return throughput * float3(0.95, 0.97, 1.0);

                    float3 hitPosition = rayOrigin + rayDirection * tHit;
                    if (hitType == 1)
                    {
                        float2 imageUv = hitPosition.xy / float2(
                            max(_CanvasAspect, 0.0001), 1.0);
                        imageUv = imageUv * 0.5 + 0.5;
                        imageUv.y = 1.0 - imageUv.y;

                        float3 image = SampleImage(imageUv, time);
                        float pathLength = inside
                            ? exp(-_Absorption * _GlassThickness / max(abs(rayDirection.z), 0.001))
                            : 1.0;
                        return throughput * image * pathLength;
                    }

                    float3 baseNormal = rayDirection.z < 0.0
                        ? float3(0.0, 0.0, 1.0)
                        : float3(0.0, 0.0, -1.0);
                    float3 normal = GlassNormal(hitPosition.xy, baseNormal, time);
                    float3 faceNormal = dot(-rayDirection, normal) >= 0.0
                        ? normal
                        : -normal;
                    float cosIncident = saturate(dot(-rayDirection, faceNormal));
                    float etaIncident = inside ? glassIor : 1.0;
                    float etaTransmitted = inside ? 1.0 : glassIor;
                    float fresnel = FresnelDielectric(
                        cosIncident,
                        etaIncident,
                        etaTransmitted);
                    float3 refracted = refract(
                        rayDirection,
                        faceNormal,
                        etaIncident / max(etaTransmitted, 0.0001));
                    bool totalInternalReflection = length(refracted) < 0.0001;
                    float randomValue = Hash12(
                        hitPosition.xy + randomSeed + bounce * 13.17);
                    bool reflectPath = totalInternalReflection ||
                        randomValue < fresnel;

                    if (reflectPath)
                    {
                        rayDirection = reflect(rayDirection, faceNormal);
                    }
                    else
                    {
                        rayDirection = normalize(refracted);
                        inside = !inside;
                    }

                    rayDirection = PerturbDirection(
                        rayDirection,
                        hitPosition.xy,
                        randomSeed + bounce * 3.17);
                    rayOrigin = hitPosition + rayDirection *
                        (inside ? -0.001 : 0.001);
                    throughput *= lerp(1.0, _GlassTint.rgb,
                        saturate(_GlassThickness * 0.12));
                    randomSeed = Hash12(
                        hitPosition.yx + randomSeed + bounce * 7.31);
                }

                return throughput * float3(0.95, 0.97, 1.0);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float safeSize = max(abs(_Size), 0.0001);
                float safeAspect = max(abs(_CanvasAspect), 0.0001);
                float2 screenPos = (input.uv * 2.0 - 1.0) *
                    float2(safeAspect, 1.0);
                screenPos = screenPos / safeSize + _Offset.xy;

                float3 cameraPosition = _CameraPos.xyz;
                float3 cameraTarget = _CameraTarget.xyz;
                float3 forward = normalize(cameraTarget - cameraPosition);
                float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
                float3 up = cross(right, forward);
                float fovScale = tan(_CameraFov * 0.5 * PI / 180.0);
                float3 rayDirection = normalize(
                    forward +
                    screenPos.x * fovScale * right +
                    screenPos.y * fovScale * up);
                float time = _Time.y * _TimeScale;
                float3 color = 0.0;

                [loop]
                for (int sampleIndex = 0;
                    sampleIndex < MAX_SAMPLES;
                    ++sampleIndex)
                {
                    if (sampleIndex >= _Samples)
                        break;

                    float2 pixel = input.uv * _ScreenParams.xy;
                    float seed = Hash12(pixel + sampleIndex * 19.19);
                    float2 jitter = (float2(
                        Hash12(pixel + sampleIndex * 3.1),
                        Hash12(pixel + sampleIndex * 7.7)) - 0.5) /
                        max(_ScreenParams.xy, 1.0);
                    float3 sampleDirection = normalize(
                        forward +
                        (screenPos.x + jitter.x) * fovScale * right +
                        (screenPos.y + jitter.y) * fovScale * up);

                    float aberration = _Aberration * 0.03;
                    float3 sampleColor;
                    if (aberration > 0.001)
                    {
                        float3 red = TraceRay(
                            cameraPosition,
                            sampleDirection,
                            -aberration,
                            time,
                            seed + 1.0);
                        float3 green = TraceRay(
                            cameraPosition,
                            sampleDirection,
                            0.0,
                            time,
                            seed + 2.0);
                        float3 blue = TraceRay(
                            cameraPosition,
                            sampleDirection,
                            aberration,
                            time,
                            seed + 3.0);
                        sampleColor = float3(red.r, green.g, blue.b);
                    }
                    else
                    {
                        sampleColor = TraceRay(
                            cameraPosition,
                            sampleDirection,
                            0.0,
                            time,
                            seed);
                    }
                    color += sampleColor;
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
