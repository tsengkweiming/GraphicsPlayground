Shader "Hidden/GraphicsPlayground/TemporalDiffusion"
{
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "Temporal Diffusion"

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            TEXTURE2D_X(_HistoryTexture);

            float4 _TD_Feedback;  // x: intensity, y: feedback, z: decay, w: motion response
            float4 _TD_Diffusion; // x: radius px, y: heat coefficient, zw: inverse resolution
            float4 _TD_Chromatic; // xy: direction, z: separation px
            float4 _TD_Flow;      // x: strength px, y: scale, z: speed, w: history validity

            float3 SampleHistory(float2 uv, float2 chromaticOffset)
            {
                float historyR = SAMPLE_TEXTURE2D_X(_HistoryTexture, sampler_LinearClamp, uv + chromaticOffset).r;
                float historyG = SAMPLE_TEXTURE2D_X(_HistoryTexture, sampler_LinearClamp, uv).g;
                float historyB = SAMPLE_TEXTURE2D_X(_HistoryTexture, sampler_LinearClamp, uv - chromaticOffset).b;
                return float3(historyR, historyG, historyB);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.texcoord;
                half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                float2 texel = _TD_Diffusion.zw;

                float phase = _Time.y * _TD_Flow.z;
                float2 flowUv = uv * _TD_Flow.y;
                float2 flow = float2(
                    sin(flowUv.y * 6.2831853 + phase) + sin((flowUv.x + flowUv.y) * 3.1415927 - phase * 0.71),
                    cos(flowUv.x * 6.2831853 - phase) + cos((flowUv.x - flowUv.y) * 3.1415927 + phase * 0.83));
                float2 historyUv = uv + flow * (0.5 * _TD_Flow.x) * texel;

                float2 sampleOffset = texel * _TD_Diffusion.x;
                float2 chromaticOffset = texel * _TD_Chromatic.xy * _TD_Chromatic.z;

                float3 center = SampleHistory(historyUv, chromaticOffset);
                float3 north = SampleHistory(historyUv + float2(0.0, sampleOffset.y), chromaticOffset);
                float3 south = SampleHistory(historyUv - float2(0.0, sampleOffset.y), chromaticOffset);
                float3 east = SampleHistory(historyUv + float2(sampleOffset.x, 0.0), chromaticOffset);
                float3 west = SampleHistory(historyUv - float2(sampleOffset.x, 0.0), chromaticOffset);

                // Explicit heat-equation step. Keeping the coefficient below 0.25 makes this
                // four-neighbour diffusion stable instead of producing runaway brightness.
                float3 diffused = center + _TD_Diffusion.y * (north + south + east + west - 4.0 * center);
                float3 history = max(diffused * _TD_Feedback.z, 0.0);

                float difference = dot(abs(source.rgb - history), float3(0.2126, 0.7152, 0.0722));
                float motion = saturate(difference * _TD_Feedback.w);
                float adaptiveFeedback = _TD_Feedback.y * lerp(0.78, 1.0, motion) * _TD_Flow.w;
                float3 accumulated = lerp(source.rgb, history, adaptiveFeedback);
                float3 result = lerp(source.rgb, accumulated, _TD_Feedback.x);

                return half4(result, source.a);
            }
            ENDHLSL
        }
    }

    Fallback Off
}
