Shader "Unlit/Vasarely3"
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

            float2x2 rotate2D(float a){ return float2x2(cos(a), -sin(a), sin(a), cos(a));}

            float smin( float d1, float d2, float k )
            {
                float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
                return lerp( d2, d1, h ) - k*h*(1.0-h);
            }
            float sdSphere(float3 p, float r)
            {
                float3 new_p = p; 
                new_p.zx = mul(rotate2D(_Time.y), new_p.zx);
                return length(new_p) - r;
            }
            float map(float3 p)
            {
                float speed = 1.5;
                float d1_fx = pow(sin(_Time.y * speed) * 1.0 + 0.8, 3.0);
                float d1_fx_two = pow(sin(_Time.y * speed + 3.0) * 1.0 + 0.8, 3.0);
                float d1 = sdSphere(p + float3(0.0,0.0, 0.5 + d1_fx), 2.0);
                float d3 = sdSphere(p + float3(-4.0,-2.0, 1.5 + d1_fx_two ), 2.0);
                float d4 = sdSphere(p + float3( 4.0,-2.0, 1.5 + d1_fx_two), 2.0);
                float d5 = sdSphere(p + float3(-4.0, 2.0, 1.5 + d1_fx_two), 2.0);
                float d6 = sdSphere(p + float3( 4.0, 2.0, 1.5 + d1_fx_two), 2.0);
                float d2 = p.z + 1.0;
                // Combine all spheres first
                float spheres = smin(d1, d3, 1.0);
                spheres = smin(spheres, d4, 1.0);
                spheres = smin(spheres, d5, 1.0);
                spheres = smin(spheres, d6, 1.0);
                return smin(spheres, d2, 3.0);
            }
            float gridLines(float3 p)
            {
                float2 cell_p = p.xy - 0.2 * floor(p.xy / 0.2) - 0.1;
                float center = length(cell_p);
                float circles = 1.0 - smoothstep(0.08, 0.08, center);
                float dist = length(p.xy);
                return circles;
            }
            /*
                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
                
                ▓               Ray Direction                  ▓
                ▓                  Normal                      ▓
                ▓                   Light                      ▓
                
                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
            */
            float rayDirection(float3 ro, float3 rd)
            {
                float dt = 0.0;
                for(int i=0; i<80; i++)
                {
                    float3 p = ro + rd * dt;
                    float d = map(p);
                    dt += d;
                    if(d < 0.0001 || dt > 20.) break;
                }
                return dt;
            }
            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.0001, 0.0);
                return normalize(float3(
                    map(p + e.xyy) - map(p - e.xyy),
                    map(p + e.yxy) - map(p - e.yxy),
                    map(p + e.yxx) - map(p - e.yxx)
                ));
            }
            float3 phongLight(float3 p, float3 norm, float3 lightDir, float3 viewDir, float3 baseColor)
            {
                
                float diff = max(dot(norm, lightDir), 0.40);
                float3 reflectDir = reflect(-lightDir, norm);
                float spec = pow(max(dot(viewDir, reflectDir), 0.0), 2.0);

                return baseColor * (diff + spec * 0.6);
            }
            /*
                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
                
                ▓                   Color                      ▓
                
                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
            */
            float3 pal( in float t, in float3 a, in float3 b, in float3 c, in float3 d )
            {
                return a + b*cos( 6.28318*(c*t+d) );
            }
            void colorPalette(int effectIndex, float2 uv, out float3 bg, out float3 rgbColor){    
                if(effectIndex == 2){
                    rgbColor = pal(uv.y,float3(0.0017,0.0241,0.165),float3(0.01133,0.0907,0.0619),float3(0.57, 0.239, 0.232),float3(0.1, 0.15, 0.3) );
                }   else {
                    rgbColor = pal(uv.y,float3(0.129,0.404,0.49),float3(0.153,0.024,0.002),float3(0.169,0.514,0.549),float3(0.153,0.424,0.502) );
                }
                bg = float3(0.631,0.847,0.969);
            }

            float3 colorGird(float3 norm, float grid, int effectIndex, float3 p)
            {
                /*–‑‑ colors –‑‑*/
                float3 bg, rgbColorTwo;
                colorPalette(effectIndex, norm.xy, bg, rgbColorTwo);
                return lerp(bg, rgbColorTwo, grid);
                // return rgbColor;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float3 linearToGamma(float3 linearColor)
            {
                // Raise the RGB channels to the power of 1/2.2
                return pow(linearColor, 1.0 / 2.2);
            }
            fixed4 frag (v2f i) : SV_Target
            {
                float2 R = _ScreenParams.xy, P;
                float2 uv = (2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y * 12.;
                float4 O;
                O -= O;
                if (abs(uv.x) > 12.) return O;
                float l;
              
                #define S(x,y) P = float2(x,y); l = length(uv-P); if (l < 5.5) uv = (uv-P) / (3.-l*l/15.) + P
                S( 0, -5);                                                                 // bubbles
                S(-6,5.6);
                S( 6,5.6);
                
                uv *= 6.28;
                float h = cos(uv.y/1.5), 
                      s = uv.x, e=100./R.y, X, Y;

                #define F(x,y,h,c1,c2,c3) X=sin(uv.r/x),Y=sin(uv.g/y); O= X*Y*h>0. ? s>-10.?c1:c2 :c3; O*= min(1.,8.*min(abs(X),abs(Y)))

                F( .87, 1.5, 1., float4(1,0,0,1), float4(.7,.4,0,1), (.4+.4*cos(s/12.)) ); // red & white faces

                if (abs(h)>.5) {
                    uv = mul(float2x2(.575,1,.575,-1), uv); // uv = mat2(.5,.5,.87,-.87)*uv/.87;
    	            F( 1.,1., h, float4(0,0,1,1), float4(.4,0,.7,1), O );                      // blue faces
               }
                
                /*  
                    X = sin(uv.x/.87), Y = sin(uv.y/1.5)                                        // red & white faces
                    O = X*Y > 0.
                        ? s>-10. ? float4(1,0,0,1) : float4(.7,.4,0,1)  
                        :  float4(.4+.4*cos(s/12.));
                    
                    O *= min(1.,8.*min(abs(X),abs(Y)));  // black line
                    
                   if (abs(h)>.5) {                                                            // blue faces
                        uv = mat2(.5,.5,.87,-.87)*uv/.87;
    	                X = sin(uv.x); Y = sin(uv.y);
                        O = X*Y*h > 0. 
        	                ? s>-10. ? float4(0,0,1,1) :  float4(.4,0,.7,1) 
                            : O;
     	                O *= min(1.,8.*min(abs(X),abs(Y)));     // black line
                    }
                */
                return O;
            }
            ENDCG
        }
    }
}
