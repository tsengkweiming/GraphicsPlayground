Shader "Hidden/CustomPostProcess/DistortionEffect"
{
    Properties
	{
        _Scale ("Scale", Range(0, 1)) = 0.25
        _Border ("Border", Range(0, 1.0)) = 0.05
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
            Name "DistortionEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            #include "Common/Noise/SimplexNoise3D.cginc"

            #pragma vertex Vert
            #pragma fragment frag
            
            float _Scale, _Speed, _T;
            float _Border;
            
            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;
                float r = _ScaledScreenParams.x / _ScaledScreenParams.y;
                float x = uv.x * r, y = uv.y;
                float2 displacement = snoise(float3(float2(x, y) * _Scale, _Time.y * _Speed)).xy;
                float s = smoothstep(0, _Border * r, uv.x) * smoothstep(1.0, 1.0 - _Border * r, uv.x) * smoothstep(0, _Border, uv.y) * smoothstep(1.0, 1.0 - _Border, uv.y);
                uv.xy += displacement * s * _T;

				float2 t = frac(uv * 0.5) * 2.0;
				float2 length = float2(1.0, 1.0);
				uv = length - abs(t - length);
                return GetSource(uv);
            }
            ENDHLSL
        }
    }
}
