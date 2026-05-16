Shader "W0NYV/DwarfTable/PostEffect/Bloom"
{
    Properties
    {
        _SamplingCount ("SamplingCount", Int) = 30
        _SamplingStepOffset ("SamplingStepOffset", int) = 0
        
        _Threshold ("Threshold", Float) = 0.4
        _Intensity ("Intensity", Float) = 1.0
        
        [Toggle(_SOFT_KNEE)]_SOFT_KNEE("SOFT_KNEE", Float) = 0
        
        _ThresholdKnee ("ThresholdKnee", Range(0.0, 1.0)) = 0.5
    }
    
    HLSLINCLUDE

        #pragma multi_compile _ _SOFT_KNEE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

        int _SamplingCount;
        int _SamplingStepOffset;
        
        half _Threshold;
        half _Intensity;
        half _ThresholdKnee;

        Texture2D _SourceTexture;

        float gauss(float x, float sigma)
        {
            float pi = acos(-1.0);
            return 1.0 / (sqrt(2.0 * pi) * sigma) * exp(-(x * x) / (2.0 * sigma * sigma));
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

        half4 frag_gaussianBlurHorizontal(Varyings i) : SV_Target
        {
            half4 col = half4(0, 0, 0, 1);

            float sum = 0;

            int samplingCount = _SamplingCount * (1 + _SamplingStepOffset);
            
            for (float x = -samplingCount; x <= samplingCount; x += 1 + _SamplingStepOffset)
            {
                float sigma = 1.0;
                float weight = gauss(x, sigma);
                col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(x, 0) * _BlitTexture_TexelSize) * weight;
                sum += weight;
            }
            
            col /= sum;
            
            return col;
        }

        half4 frag_gaussianBlurVertical(Varyings i) : SV_Target
        {
            half4 col = half4(0, 0, 0, 1);

            float sum = 0;

            int samplingCount = _SamplingCount * (1 + _SamplingStepOffset);

            for (float y = - samplingCount; y <= samplingCount; y+= 1 + _SamplingStepOffset)
            {
                float sigma = 1.0;
                float weight = gauss(y, sigma);
                col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(0, y) * _BlitTexture_TexelSize) * weight;
                sum += weight;
            }
            
            col /= sum;
            
            return col;
        }

        half4 frag_dest(Varyings i) : SV_Target
        {
            half4 blurTex = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, i.texcoord);
            half4 sourceTex = SAMPLE_TEXTURE2D_X(_SourceTexture, sampler_LinearClamp, i.texcoord);
            
            return sourceTex + blurTex * _Intensity;
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
            #pragma fragment frag_gaussianBlurHorizontal;
            
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag_gaussianBlurVertical;
            
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert;
            #pragma fragment frag_dest;
            
            ENDHLSL
        }
    }
}