Shader "GraphicsPlayground/Physarum Display"
{
    Properties
    {
        [HideInInspector] _TrailTexture("Trail", 2D) = "black" {}
        [HideInInspector] _ParticleTexture("Particles", 2D) = "black" {}
        [HideInInspector] _DisplayMode("Display Mode", Float) = 2
        [HDR] _BackgroundColor("Background", Color) = (0.003, 0.005, 0.012, 1)
        [HDR] _ShadowColor("Shadow", Color) = (0.02, 0.08, 0.16, 1)
        [HDR] _MidColor("Mid", Color) = (0.1, 0.85, 0.75, 1)
        [HDR] _HighlightColor("Highlight", Color) = (1, 0.75, 0.2, 1)
        _TrailExposure("Trail Exposure", Float) = 0.55
        _ParticleExposure("Particle Exposure", Float) = 1.4
        _Contrast("Contrast", Range(0.1, 3)) = 0.75
        _ColorSplit("Color Split", Range(0.05, 0.95)) = 0.48
        _ParticleHighlight("Particle Highlight", Range(0, 1)) = 0.7
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "PhysarumDisplay"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
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
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_TrailTexture);
            SAMPLER(sampler_TrailTexture);
            TEXTURE2D(_ParticleTexture);
            SAMPLER(sampler_ParticleTexture);

            CBUFFER_START(UnityPerMaterial)
                half4 _BackgroundColor;
                half4 _ShadowColor;
                half4 _MidColor;
                half4 _HighlightColor;
                float _TrailExposure;
                float _ParticleExposure;
                float _Contrast;
                float _ColorSplit;
                float _ParticleHighlight;
                float _DisplayMode;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float trailRaw = SAMPLE_TEXTURE2D(_TrailTexture, sampler_TrailTexture, input.uv).r;
                float particleRaw = SAMPLE_TEXTURE2D(_ParticleTexture, sampler_ParticleTexture, input.uv).r;
                float trail = 1.0 - exp(-max(trailRaw, 0.0) * max(_TrailExposure, 0.0));
                float particles = 1.0 - exp(-max(particleRaw, 0.0) * max(_ParticleExposure, 0.0));

                float particlesOnly = 1.0 - step(0.5, abs(_DisplayMode - 1.0));
                float trailOnly = 1.0 - step(0.5, abs(_DisplayMode));
                float showTrail = 1.0 - particlesOnly;
                float showParticles = 1.0 - trailOnly;
                float intensity = saturate(trail * showTrail + particles * showParticles);
                intensity = pow(max(intensity, 1e-5), max(_Contrast, 0.1));

                float split = clamp(_ColorSplit, 0.05, 0.95);
                float lowBlend = smoothstep(0.0, split, intensity);
                float highBlend = smoothstep(split, 1.0, intensity);
                half3 trailColor = lerp(_ShadowColor.rgb, _MidColor.rgb, lowBlend);
                trailColor = lerp(trailColor, _HighlightColor.rgb, highBlend);
                trailColor = lerp(trailColor, _HighlightColor.rgb, particles * _ParticleHighlight);
                half3 color = lerp(_BackgroundColor.rgb, trailColor, intensity);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
