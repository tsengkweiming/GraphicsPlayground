Shader "Hidden/CustomPostProcess/InverseEffect"
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
            Name "InverseEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            #include "Common/Noise/SimplexNoise2D.cginc"
			#include "Common/Random.cginc"
            
            #pragma vertex Vert
            #pragma fragment frag
            
            half _T, _Scale, _Power;

            float fbm(float2 P, float lacunarity, float gain)
			{
				float sum = 0.0;
				float amp = 1.0;
				float2 pp = P;
				for (int i = 0; i < 4; i += 1)
				{
					amp *= gain;
					sum += amp * (snoise(pp) + 1.0) * 0.5;
					pp *= lacunarity;
				}
				return sum;
			}
            
            half4 frag(Varyings input):SV_Target
            {
                float4 color = GetSource(input);

                float2 uv = input.uv;
            	
            	float s = nrand(float2(uv.y, _Time.x));
				float n = (snoise(float2(_Time.y + step(s, uv.x) * _Scale, uv.y * _Scale)) + 1.0) * 0.5;
				float t = step(pow(n, _Power), _T);
                color.rgb = lerp(color.rgb, 1.0 - color.rgb, t);
                return color;
            }
            ENDHLSL
        }
    }
}
