Shader "Unlit/SimpleSquareOpticalIllusion"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color1 ("Color 1", COlor) = (0, 0.1, 0.55)
        _Color2 ("Color 2", COlor) = (0.85, 0.1, 0.55)
        
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
            float4 _Color1;
            float4 _Color2;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #ifndef PI
            #define PI 3.1415926535897932384626433832795
            #endif

            float2 rotate2D( in float2 uv, in float alpha )
            {
                float c = cos(alpha);
                float s = sin(alpha);
                uv =  mul(float2x2(c, -s, s, c), uv - 0.5) + 0.5;
                return uv;
            }

            float2 tile(in float2 uv, float zoom)
            {
                return frac(uv * zoom);
            }

            float box( in float2 uv, in float2 size, in float smoothEdges )
            {
                size = 0.5 - size * 0.5;
                float2 aa = smoothEdges*0.5;
                float2 st = smoothstep( size, size+aa, uv)
                      * smoothstep( size, size+aa, 1.0 - uv);    
                return st.x * st.y;
            }

            float circle( in float2 uv, in float radius, in float smoothEdges )
            {
                // 1. Calculate the distance of the current pixel from the center (0.5, 0.5)
                float d = length(uv - 0.5); // Note: Use float2 if writing in HLSL/Cg
                
                // 2. Define the half-width of our smoothing transition range
                float aa = smoothEdges * 0.5;
                
                // 3. Smoothly transition from 1.0 (inside radius) to 0.0 (outside radius)
                // We invert the smoothstep order so it returns 1.0 on the inside
                return smoothstep(radius + aa, radius - aa, d);
            }

            float sdCircle( float2 p, float r )
            {
                return length(p) - r;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // float2 uv = i.uv;
                float2 uv = (2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y;

                float shiftAngle = PI * 0.25;
                // float angle = mod( 1.0 * _Time.y, PI) + shiftAngle;
                float angle = _Time.y - PI * floor(_Time.y / PI) + shiftAngle;
                float doShift = step(angle, PI-shiftAngle);
                float2 shiftOffset = float2(-0.5, 0.5) / 5.0;
                
                uv += doShift * shiftOffset;
                uv = tile(uv, 5.0);
                uv = rotate2D(uv, angle);

                float ic = abs(box(uv, float2(0.71, 0.71), 0.012) - doShift) - sdCircle(uv - 0.5, 0.2);
                // float ic = (sdCircle(uv - 0.5, 0.4) - 0);
                float3 col = ic > 0 ? _Color1 : _Color2;
                return float4(col, 1.0);
                return float4(ic,ic,ic, 1.0);
                return float4(float3(0.85*ic , 0.1, 0.55), 1.0);
            }
            ENDCG
        }
    }
}
