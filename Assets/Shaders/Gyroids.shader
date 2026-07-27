Shader "Unlit/Gyroids"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Palette_A ("Palette_A", Vector) = (0.45, 0.45, 0.45)
        _Palette_B ("Palette_B", Vector) = (0.35, 0.35, 0.35)
        _Palette_C ("Palette_C", Vector) = (1, 1, 1, 1)
        _Palette_D ("Palette_D", Vector) = (0.7, 0.39, 0.2)
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
            float3 _Palette_A;
            float3 _Palette_B;
            float3 _Palette_C;
            float3 _Palette_D;

            // based on https://iquilezles.org/articles/palettes/
            float3 pal(float t) {
                float3 a = _Palette_A;
                float3 b = _Palette_B;
                float3 c = _Palette_C;
                float3 d = _Palette_D;
                return a+b*cos(UNITY_TWO_PI*(c*t+d));
            }

            // see https://www.youtube.com/watch?v=-adHIyjIYgk
            float gyroid(float3 p, float scale) {
                p *= scale;
                float bias = lerp(1.1, 2.65, sin(_Time.y*.4 + p.x/3. + p.z/4.)*.5+.5);
                float g = abs(dot(sin(p*1.01), cos(p.zxy*1.61)) - bias)/(scale*1.5)-.1;
                return g;
            }

            float scene(float3 p) {
                float g1 = .7*gyroid(p, 4.);
                return g1;
            }

            // from @blackle
            float3 norm(float3 p) {
                float3x3 k = float3x3(p,p,p) - 0.01;
                return normalize(scene(p) - float3(scene(k[0]),scene(k[1]),scene(k[2])));
            }
                        
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f IN) : SV_Target
            {
                float2 uv = (IN.vertex.xy - 0.5 * _ScreenParams.xy) / _ScreenParams.y;
                float3 init = float3(_Time.y*.25,1.5,.3);
                float3 cam = normalize(float3(1., uv ));

                // basic raymarcher from @blackle
                float3 p = init;
                bool hit = false;
                for ( int i = 0; i < 100 && !hit; i++) {
                    if (distance(p,init) > 8.) break;
                    float d = scene(p);
                    if (d*d < 0.00001) hit = true;
                    p += cam*d;
                }
                float3 n = norm(p);

                float ao = 1.-smoothstep(-.3,.75,scene(p+n*.4))
                         * smoothstep(-3.,3.,scene(p+n*1.));
                
                float  fres = -max(0., pow(.8-abs(dot(cam,n)), 3.));
                float3 vign = smoothstep(0.,1.,1.-(length(uv*.8)-.1));
                float3 col = pal(.1-_Time.y*.01 + p.x*.28 + p.y*.2 + p.z*.2);
                col = (fres+col)*ao;
                col = lerp(col, 0., !hit ? 1. : smoothstep(0.,8.,distance(p,init)));
                col = lerp(0,col, vign+.1);
                col = smoothstep(0.,1.+.3*sin(_Time.y+p.x*4.+p.z*4.),col);
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
