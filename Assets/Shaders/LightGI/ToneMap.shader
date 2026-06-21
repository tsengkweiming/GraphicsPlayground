Shader "LightGI/ToneMap"
{
    // Used with Graphics.Blit — reads the HDR accumulation buffer,
    // applies Reinhard tone mapping and sRGB gamma correction.
    // _MainTex is set automatically by Graphics.Blit.

    Properties
    {
        _MainTex ("Accumulated GI Buffer (HDR)", 2D) = "black" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = v.uv;
                return o;
            }

            float3 reinhard(float3 c)
            {
                return c / (c + 1.0);
            }

            float3 linearToSRGB(float3 c)
            {
                // Piecewise sRGB — more accurate than a straight pow(c, 1/2.2)
                float3 lo = c * 12.92;
                float3 hi = 1.055 * pow(saturate(c), 1.0 / 2.4) - 0.055;
                return lerp(lo, hi, step(0.0031308, c));
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 hdr = tex2D(_MainTex, i.uv).rgb;
                float3 sdr = linearToSRGB(reinhard(hdr));
                return 1;
                return fixed4(sdr, 1.0);
            }
            ENDCG
        }
    }
}