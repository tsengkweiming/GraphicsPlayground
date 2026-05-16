Shader "W0NYV/DwarfTable/PostEffect/BoxFilteringBloom"
{
    Properties
    {
        _Intensity ("Intensity", Float) = 1.0
        
        _Threshold ("Threshold", Float) = 0.4
        _ThresholdKnee ("ThresholdKnee", Range(0.0, 1.0)) = 0.5
        
        [Toggle(_SOFT_KNEE)]_SOFT_KNEE("SOFT_KNEE", Float) = 0
    }
    
    HLSLINCLUDE

        #pragma multi_compile _ _SOFT_KNEE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

        half _Threshold;
        half _Intensity;
        half _ThresholdKnee;

        Texture2D _SourceTexture;
        
        half3 sampleMain(float2 uv)
        {
            return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv).rgb;
        }

        half3 sampleBox(float2 uv, float delta)
        {
            float4 offset = _BlitTexture_TexelSize.xyxy * float2(-delta, delta).xxyy;
            half3 sum = sampleMain(uv + offset.xy) + sampleMain(uv + offset.zy) + sampleMain(uv + offset.xw) + sampleMain(uv + offset.zw);
            return sum * 0.25;
        }

        half4 frag_brightness(Varyings i) : SV_Target
        {
            half4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.texcoord);

            half brightness = max(col.r, max(col.g, col.b));

            #if _SOFT_KNEE
                half softness = clamp(brightness - _Threshold + _ThresholdKnee, 0.0, 2.0 * _ThresholdKnee);
                softness = (softness * softness) / (4.0 * _ThresholdKnee + 1e-4);
                half multiplier = max(brightness - _Threshold, softness) / max(brightness, 1e-4);

                return col * multiplier;
            #else
                brightness *= step(_Threshold, brightness);
                return col * brightness;
            #endif
        }

        half4 frag_downSampling(Varyings i) : SV_Target
        {
            half4 col = half4(0, 0, 0, 1);
            col.rgb = sampleBox(i.texcoord, 1.0);
            return col;
        }

        half4 frag_upSampling(Varyings i) : SV_Target
        {
            half4 col = half4(0, 0, 0, 1);
            col.rgb = sampleBox(i.texcoord, 0.5);
            return col;
        }

        half4 frag_lastUpSampling(Varyings i) : SV_Target
        {
            half4 col = SAMPLE_TEXTURE2D_X(_SourceTexture, sampler_LinearClamp, i.texcoord);
            col.rgb += sampleBox(i.texcoord, 0.5) * _Intensity;
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
            #pragma fragment frag_brightness;
            
            ENDHLSL
        }
        
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag_downSampling;
            
            ENDHLSL
        }

        Pass
        {
            Blend One One
            
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag_upSampling;
            
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag_lastUpSampling;
            
            ENDHLSL
        }
    }
}