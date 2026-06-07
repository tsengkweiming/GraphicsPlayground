Shader "PostEffectGraph/BlurModule"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue" = "Geometry"
        }

        Cull Off
        ZWrite Off
        ZTest Always

        HLSLINCLUDE
        #include "Assets/Shaders/Runtime/Shaders/ScreenRenderingVert.hlsl"
        #include "Assets/Shaders/Runtime/Shaders/Blur.hlsl"

        Texture2D _MainTex;
        float4 _MainTex_TexelSize;
        SamplerState sampler_linear_clamp;

        float2 _Direction;
        float _SampleStep;

        /**
        * @brief Gaussian Blur
        */
        half4 GaussianBlur(ScreenRenderingVaryings i) : SV_Target
        {
            half3 color = ApplyBlur(_MainTex, sampler_linear_clamp, i.uv, _MainTex_TexelSize.xy, _Direction, _SampleStep);
            return half4(color, 1.0);
        }

        half4 DownSample(ScreenRenderingVaryings i) : SV_Target
        {
	        half3 color = DownSample(_MainTex, sampler_linear_clamp, i.uv, _MainTex_TexelSize.xy, _SampleStep);
	        return half4(color, 1.0);
        }

        half4 UpSample(ScreenRenderingVaryings i) : SV_Target
        {
	        half3 color = UpSample(_MainTex, sampler_linear_clamp, i.uv, _MainTex_TexelSize.xy, _SampleStep);
	        return half4(color, 1.0);
        }
        ENDHLSL

        Pass // 0
        {
            HLSLPROGRAM
            #pragma multi_compile BLUR_LOW BLUR_NORMAL BLUR_HIGH BLUR_VERYHIGH BLUR_ULTRA
            #pragma vertex ScreenRenderingVert
            #pragma fragment GaussianBlur
            ENDHLSL
        }

        Pass // 1
        {
            HLSLPROGRAM
            #pragma vertex ScreenRenderingVert
            #pragma fragment DownSample
            ENDHLSL
        }

        Pass // 2
        {
            HLSLPROGRAM
            #pragma vertex ScreenRenderingVert
            #pragma fragment UpSample
            ENDHLSL
        }
    }
}