Shader "Hidden/CustomPostProcess/BackgroundGradientEffect"
{
	Properties
	{
		_T ("T", Range(0, 1)) = 1.0
		_Scale ("Scale", Float) = 35.0
		_Power ("Power", Range(0.1, 2.0)) = 0.75
	}
    SubShader
    {
        Tags { "RenderType"="Opaque"
               "RenderPipeline"="UniversalPipeline"
        }
        LOD 200
        ZWrite Off
        Cull off
        Pass
        {
            Name "BackgroundGradientEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            
            #pragma vertex Vert
            #pragma fragment frag
            
            float4 _GradientColor0, _GradientColor1, _GradientColor2, _GradientColor3, _GradientColor4;
			float4 _Pos0123;
			float _T;
            
            half4 frag(Varyings input):SV_Target
            {
                float4 color = GetSource(input);

                float2 uv = input.uv;

            	float4 finalColor;
                finalColor = lerp(_GradientColor0, _GradientColor1, smoothstep(_Pos0123.x, _Pos0123.y, uv.y));
                finalColor = lerp(finalColor,      _GradientColor2, smoothstep(_Pos0123.y, _Pos0123.z, uv.y));
                finalColor = lerp(finalColor,      _GradientColor3, smoothstep(_Pos0123.z, _Pos0123.w, uv.y));
                finalColor = lerp(finalColor,      _GradientColor4, smoothstep(_Pos0123.w, _Pos0123.x, uv.y));
            	
                color.rgb = lerp(color.rgb, finalColor, _T);
                return color;
            }
            ENDHLSL
        }
    }
}
