Shader "Hidden/PostEffect/CrossEffect"
{
    Properties
    {
        _FrameBlend ("Frame Blend", Range(0,1)) = 1.0
    }
    
    HLSLINCLUDE

        #pragma multi_compile _ _SOFT_KNEE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

        half _FrameBlend;

        Texture2D _SourceTexture;
        
        float3 hash(float3 x)
        {
            uint3 v = asuint(x);
            v = v * 1664525u + 1013904223u;
            v.x += v.y * v.z;
            v.y += v.z * v.x;
            v.z += v.x * v.y;
            v ^= (v >> 16);
            v.x += v.y * v.z;
            v.y += v.z * v.x;
            v.z += v.x * v.y;
            return (float3)(v) / 4294967295.0; // normalize using float(-1u)
        }

        half4 frag(Varyings i) : SV_Target
        {
            half4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.texcoord);

            float2 uv = i.texcoord;

            float bpm = 240.0 / 140.0;
            float alt = _Time.y / bpm;

            float2 asp = _ScaledScreenParams.x / _ScaledScreenParams.y;

            float2 suv = (uv * 2.0 - 1.0) * asp;
            float2 ruv = suv * 8.0;
            float2 auv = abs(frac(ruv) - 0.5);

            float3 effect = 0;

            if (hash(ceil(float3(ruv, alt * 16.0))).x < 0.1)
            {
                if (any(auv < 0.02) && all(auv < 0.3))
                    effect += 1.0;
            }

            effect += step(abs(uv.y - 0.1), 0.03) *
                   step(abs(uv.x - 0.5), 0.5 * frac(alt)) *
                   step(frac(dot(float2(1, 1), suv) * 20.0 + 10.0 * alt), 0.5);
            col.rgb = lerp(col.rgb, effect, _FrameBlend);
            return col;
        }
        
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off
        
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag;
            
            ENDHLSL
        }
    }
}