Shader "Hidden/CustomPostProcess/PixelSort"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 200
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "PixelSort"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Fragment

            #include "Common/CustomPostProcessing.hlsl"

            float _Intensity;
            float _Threshold;
            float _ThresholdSoftness;
            float _StreakLength;
            float _Samples;
            float _BrightnessPower;
            float _BreakUp;
            float _Horizontal;
            float _Reverse;
            float _AnimationAmount;
            float _AnimationSpeed;
            float4 _SourceTexelSize;

            float Hash21(float2 value)
            {
                value = frac(value * float2(123.34, 456.21));
                value += dot(value, value + 45.32);
                return frac(value.x * value.y);
            }

            float SortLuminance(float3 color)
            {
                return pow(saturate(GetLuminance(color)), _BrightnessPower);
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                half4 original = GetSource(uv);
                float originalLuminance = SortLuminance(original.rgb);

                // A normalized axis keeps the same controls valid at every
                // aspect ratio. _Reverse is deliberately sign-only so the
                // shader remains branch-free on mobile GPUs.
                float2 axis = lerp(float2(0.0, 1.0), float2(1.0, 0.0), saturate(_Horizontal));
                float direction = lerp(1.0, -1.0, saturate(_Reverse));
                float timePhase = _Time.y * _AnimationSpeed;
                float animatedDirection = lerp(direction, direction * (0.35 + 0.65 * sin(timePhase) * 0.5 + 0.325),
                    saturate(_AnimationAmount));
                float2 pixelStep = axis * _SourceTexelSize.xy * animatedDirection;
                float2 noiseCoord = uv * _SourceTexelSize.zw + floor(timePhase * 7.0);
                float localNoise = Hash21(noiseCoord);
                float localThreshold = _Threshold + (localNoise - 0.5) * _BreakUp;
                float softness = max(_ThresholdSoftness, 0.0001);

                float bestLuminance = originalLuminance;
                half3 bestColor = original.rgb;
                float bestEligibility = smoothstep(localThreshold - softness, localThreshold + softness,
                    originalLuminance);

                // The reference uses repeated neighbor comparisons. A
                // bounded max-selection pass produces the same bright-pixel
                // column stretching in one URP post-process pass, without a
                // feedback texture or an unbounded raymarch-style loop.
                [loop]
                for (int sampleIndex = 1; sampleIndex <= 32; sampleIndex++)
                {
                    float sampleActive = step((float)sampleIndex - 0.5, _Samples);
                    float sampleT = (float)sampleIndex / max(_Samples, 1.0);
                    float2 sampleUv = saturate(uv + pixelStep * (_StreakLength * sampleT));
                    half3 sampleColor = GetSource(sampleUv).rgb;
                    float sampleLuminance = SortLuminance(sampleColor);
                    float eligible = smoothstep(localThreshold - softness, localThreshold + softness,
                        sampleLuminance);
                    float brighter = step(bestLuminance + 0.0001, sampleLuminance);
                    float replace = sampleActive * eligible * brighter;

                    bestColor = lerp(bestColor, sampleColor, replace);
                    bestLuminance = lerp(bestLuminance, sampleLuminance, replace);
                    bestEligibility = max(bestEligibility, eligible * sampleActive);
                }

                float transfer = smoothstep(0.02, 0.35, bestEligibility);
                transfer *= saturate(1.0 - abs(originalLuminance - _Threshold) * 0.15);
                float effect = saturate(_Intensity * transfer);
                half3 color = lerp(original.rgb, bestColor, effect);
                return half4(color, original.a);
            }
            ENDHLSL
        }
    }
}
