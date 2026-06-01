Shader "Hidden/CustomPostProcess/BlockEffect"
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
            Name "BlockEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            #include "Common/Noise/SimplexNoise3D.cginc"

            #pragma vertex Vert
            #pragma fragment frag
            
            float _Speed, _Shift;
			float2 _ScaleS, _ScaleL;

			float _T;
	
			float rng2(float2 seed)
			{
			    return frac(sin(dot(seed * floor(_Time.y * _Speed), float2(127.1, 311.7))) * 43758.5453123);
			} 

			float rng(float seed)
			{
			    return rng2 (float2 (seed, 1.0));
			}

            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;
            	
            	float2 blockS = floor(uv * _ScaleS);
				float2 blockL = floor(uv * _ScaleL);

            	float lineNoise = pow(rng2(blockS), 8.0) * pow(rng2(blockL), 3.0) - pow(rng(7.2341), 17.0) * 2.0;
	    
			    float4 col1 = GetSource(uv);
			    float4 col2 = GetSource(uv + float2(lineNoise * _Shift * rng( 5.0), 0));
			    float4 col3 = GetSource(uv - float2(lineNoise * _Shift * rng(31.0), 0));
	    
				float4 rgb = lerp(col1, float4(float3(col1.x, col2.y, col3.z), 1.0), _T);
				rgb.a = col1.a;
				return rgb;
            }
            ENDHLSL
        }
    }
}
