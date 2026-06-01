Shader "Unlit/FolklorePlanetaire"
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
            #define N_tile 30.

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

            float3 mix4ColorGradient(float ratio, float3 start, float3 mid1, float3 mid2, float3 end){
                return
                lerp(
                    lerp(
                        lerp(start, mid1, ratio/.33), lerp(mid1, mid2, (ratio - .33)/.66), 
                        step(.33, ratio)), 
                    lerp(mid2, end, (ratio-.66)/.33), 
                        step(.66, ratio));
            }

            float2 hash( float2 p )
            {
                //p = mod(p, 4.0); // tile
                p = float2(dot(p,float2(175.1,311.7)),
                         dot(p,float2(260.5,752.3)));
                return frac(sin(p+455.)*18.5453);
            }

            float3 random_color(float2 p)
            {
                return float3(hash(p).x, hash(2.*p).x, hash(3.*p).x);
            }

            float3 make_cell(float2 tile_coord, float2 tile_idx, float3 background_noise){
                
                float3 res = float3(0, 0, 0);
                float length_coord = length(tile_coord);
                float l_inf_coord = max(abs(tile_coord.x), abs(tile_coord.y));
                float radius = (0.35 + hash(tile_idx).x*.5)/2.;
                
                float activation_int = 1.-smoothstep(radius-0.04, radius+0.04, length_coord);
                float activation_contour = smoothstep(.47, .5, l_inf_coord);
                
                float3 color_int = activation_int*random_color(tile_idx);
                float3 color_cell = (1.-activation_int)*background_noise*(1.-activation_contour);
                float3 color_ext = activation_contour*float3(0., 0., 0.);

                res = color_int+color_cell+color_ext;
                return res;
            }

            // 2D Noise based on Morgan McGuire @morgan3d
            // https://www.shadertoy.com/view/4dS3Wd
            float noise (in float2 st) {
                float2 i = floor(st);
                float2 f = frac(st);
                float a = hash(i).x;
                float b = hash(i + float2(1.0, 0.0)).x;
                float c = hash(i + float2(0.0, 1.0)).x;
                float d = hash(i + float2(1.0, 1.0)).x;
                float2 u = f*f*(3.0-2.0*f);
                return lerp(a, b, u.x) +
                        (c - a)* u.y * (1.0 - u.x) +
                        (d - b) * u.x * u.y;
            }

            float fbm( in float2 x)
            {    
                float t = 0.0;
                for( int i=0; i<6; i++ )
                {
                    float f = pow( 2.0, float(i) );
                    float a = pow( f, -1. );
                    t += a*noise(f*x);
                }
                return t*1.-.4;
            }
            
            float3 linearToGamma(float3 linearColor)
            {
                // Raise the RGB channels to the power of 1/2.2
                return pow(linearColor, 1.0 / 2.2);
            }
            
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
                // Normalized pixel coordinates (from 0 to 1)
                // float2 uv = i.uv - 0.5;
                float2 uv = (2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y;

                float2 pos = float2(uv*6.0);

                float2 tile_coord = frac(uv*N_tile)-.5;
                float2 tile_idx = floor(uv*N_tile)-.5;
                
             
                // Use the noise function
                float reshape = 16.;
                
                float2 tmp = sin( float2(0.27+_Time.y/2000.,0.23)*_Time.y + .1*length(tile_idx)*float2(2.1,2.3))+tile_idx*.1;
                
                float n = fbm(tmp+fbm(tmp));
                
                float3 color_low = float3(5., 0., 40.);
                float3 color_mid1 = float3(30., 80., 20.);
                float3 color_mid2 = float3(210., 20., 60.);
                float3 color_high = float3(210., 230., 0.);
                
                float3 background_color = mix4ColorGradient(n, color_low, color_mid1, color_mid2, color_high);
                background_color = normalize(background_color);
                
                float3 color = make_cell(tile_coord, tile_idx, background_color);
                // color = linearToGamma(color);
                // color = pow(color, 1.2);
                
                return float4(color, 1);
            }
            ENDCG
        }
    }
}
