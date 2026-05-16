Shader "Unlit/CircleAberrations"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                float2 uv = i.uv;

                uv *= 5.;
                
                
                float2 gv = frac(uv * 1.);
                
                float3 col = float3(0.0, 0.0, 0.0);
                
                for(float x = -1.; x <= 1.; x+=1.){
                     for(float y = -1.; y <= 1.; y++){
                         
                        float2 offs = float2(x,y);
                        float2 center = floor(uv)+0.5 + offs;
                         
    		            float r = smoothstep(.3, 0.25, length(uv + 0.5 * sin(_Time.y*2.) - center));    
    		            float g = smoothstep(.3, 0.25, length(uv + 1.0 * cos(_Time.y)    - center));    
    		            float b = smoothstep(.65, 0.25, length(uv - center));
                
    		            col += float3(r, g, b);
                     }
                }
                return float4(col, 1);
            }
            ENDCG
        }
    }
}
