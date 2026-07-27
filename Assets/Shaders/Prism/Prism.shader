Shader "Unlit/Prism"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }
            /*
                Centered the original and switched the torus for a square prism
            */
            fixed4 frag(v2f IN) : SV_Target
            {
                //Camera depth
                float z = 5.,
                //Raymarch step distance
                d,
                //Raymarch iterator
                i = 0;
                
                //Center and scale uvs
                float2 coord = (IN.vertex.xy - .5*_ScreenParams.xy)/_ScreenParams.y/.1;
                
                //3D sample point
                float3 p;
                float4 col = 0;
                //Raymarch loop (100 steps)
                for(col*=i; i++<1e2;
                    //Sample coloring (attenuate with distance)
                    col += (sin(p.y+z+float4(0,1,2,3))+1.)/d)
                    
                    //Raymarch sample point
                    p = float3(coord,z),
                    //Rotated about y-axis
                    p.xz = mul(float2x2(cos(_Time.y+float4(0,33,11,0))), p.xz),
                    //The new line
                    z -= d = .1+.2*abs((max(abs(p.x)+abs(p.y),abs(p.z))-3.5)/1.732);
                //Tanh tonemap
                //https://mini.gmshaders.com/p/func-tanh
                col=tanh(col*col/1e5);
                return col;
            }
            ENDCG
        }
    }
}