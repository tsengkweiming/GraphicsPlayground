Shader "Unlit/HexStairs"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RayOrigin ("Ray Origin", Vector) = (0,7.2,-14.)
        _LookAt ("LookAt", Vector) = (-1,-3,0.5)
        _RoomSize ("Room Size", Vector) = (4.0, 4.0, 4.0)
        _Color1 ("Color 1", COlor) = (0, 0.1, 0.55)
        _Color2 ("Color 2", COlor) = (0.7, 0.5, 0.3)
        _SphereCenter ("Sphere Center", Vector) = (0.0, -1.0, 0.0)
        _SphereSize ("Sphere Size", Float) = 1.2
        _Ambient ("Ambient", Float) = 0.05
        _TileZoom ("TileZoom", Float) = 5
        _UVLerp ("UV Lerp", Range(0,1)) = 1
        [Toggle(Light Switch)]_LightSwitch ("Light Switch", Float) = 1
        [Toggle(DivTest Switch)]_DivSwitch ("Div Switch", Float) = 1
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
            float3 _RayOrigin;
            float3 _LookAt;
            float3 _RoomSize;
            float4 _Color1;
            float4 _Color2;
            float3 _SphereCenter;
            float _SphereSize;
            float _Ambient;
            float _TileZoom;
            float3 _Mouse;
            float _LightSwitch;
            float _DivSwitch;
            float _UVLerp;
            
            #ifndef PI
            #define PI 3.1415926535897932384626433832795
            #endif

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            // variant of "hexastairs"  https://shadertoy.com/view/3sGfWm
            // using "hexa world" https://shadertoy.com/view/tsKBDD

            #define H(I)   frac(1e4*sin(1e4*length(float2(I.xy))))         // cheap hash
            //#define H(I) hash(uvec3(I.xy,0))                         // the one used in "hexa world": integer hash from https://www.shadertoy.com/view/XlXcW4
            #define h(x,y) int( 4.* H( I + int3(x,y,0) ) )            // O-3 random int at relative cell(dx,dy)

            float3 mod(float3 x, float3 y)
            {
                return x - y * floor(x / y);
            }

            fixed4 frag (v2f IN) : SV_Target
            {
                float wrappedTime = fmod(_Time.y, 100.0);
                // Normalized pixel coordinates (from -1 to 1)
                // float2 uv = (2.0 * IN.vertex.xy - _ScreenParams.xy) / _ScreenParams.y / 2.0;
                float2 uv = IN.vertex.xy / _ScreenParams.y;
                float2 p = (2.0 * uv -  _ScreenParams.xy / _ScreenParams.y) / 2.0;
                float2 R = _ScreenParams.xy, 
                       U = 12.* IN.vertex.xy / R.y + wrappedTime;          // === std hexagonal tiling data

                U = mul(float2x2(1,0,.5,.87), U);                          // parallelogram frame
                float3  V = float3( U, U.y-U.x +3. );                      // 3 axial coords
                int3 I = int3(floor(V)), J;
                     I += I.yzx;
                     J = I % 3;                                       // J.xy = ~ hexagon face
                int   f = J.x==2 ? 1 : J.y==2 ? 2 : 0,                 // f: front face id 
                      b = J.x==1 ? 1 : J.y==0 ? 2 : 0, k,o=0;          // b: back face id
                I.x += 4; I /= 3;                                      // I.xy = hexagon id
                V = mod( V + float3( I.y, I.y+I.x, I.x ), 2. );          // local coords
                k = h(0,0);                                            // rand values per hexagon
                
                                                                       // === custom hexatile pattern drawing
                if (k==3) {                                            // --- plain cubes (i.e. stairless)
                    k = f+2;                                           // base color = face id
            #define check(i,j,s, X,Y)  \
                         if (h( i, j)==s && abs(X-1.5)<.25 && Y<.75)  k++
                         check(-f,-1, 1-f,  V.x+float(f), V[2-f] );    // regular doors
                    else check( 0, 1,  1,   V.y   , 2.-V.z );          // horiz doors
                    else check( 1, 1,  0,   V.z   , 2.-V.y );         
                    else check(-1, 0,  2,   V.y+1.,  V.x   );          // tilted doors
                    else check( 1, 0,  2,   V.z+1., 2.-V.x );             
                }
                // else {                                                 // --- cubes with stairs
                //     float s=1.,f=1.,l=1.;
                //     V = k==1 ? f=-f, l=0., V.yzx                       // apply random hexagon rotation
                //       : k==2 ? s=-s, V.yxz : V;
                //     s *= mod(8.*V.y+l,2.) - 1.;                        // stair striping
                //     l =  2.*V.x-V.y +(abs(s)-9.)/8.;                   // stair dented slope
                //     k =  f*( 2.*V.x-V.y-1.)>.5 || -f*l>.5 ? o=1, b+2   // draw rear faces. set o for ambiant occlusion
                //        : f*l > .3 ? k+2                                // draw stair sides
                //        :  s  < 0. ? k+1 : k;                           // draw stair steps
                // }
                else {                                                 // --- cubes with stairs
                    float s = 1.0;
                    float f_stair = 1.0;
                    float l = 1.0;
                    
                    // --- Unpacked GLSL ternary chaining into clean HLSL if-else statements
                    if (k == 1) {
                        f_stair = -f_stair; 
                        l = 0.0; 
                        V = V.yzx;                                     // apply random hexagon rotation
                    } 
                    else if (k == 2) {
                        s = -s; 
                        V = V.yxz;
                    }
                    
                    s *= mod(8.0 * V.y + l, 2.0) - 1.0;                // stair striping
                    l = 2.0 * V.x - V.y + (abs(s) - 9.0) / 8.0;        // stair dented slope
                    
                    // --- Unpacked the final color/occlusion calculation
                    if (f_stair * (2.0 * V.x - V.y - 1.0) > 0.5 || -f_stair * l > 0.5) {
                        o = 1;                                         // set o for ambient occlusion
                        k = b + 2;                                     // draw rear faces
                    } 
                    else if (f_stair * l > 0.3) {
                        k = k + 2;                                     // draw stair sides
                    } 
                    else {
                        k = (s < 0.0) ? k + 1 : k;                     // draw stair steps
                    }
                }
                float4 O = k%3/2.;
                if (o>0) O *= min(1.,length(V-1.)*.8);                 // ambiant occlusion behind stairs
                return O;
            }
            ENDCG
        }
    }
}
