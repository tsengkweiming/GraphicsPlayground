Shader "Unlit/Microtorus"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle(Direction Switch)] _DirSwitch ("Direction Switch", Float) = 0
        _SwipeOffset ("Swipe Offset", Vector) = (0, 0, 0, 0)
        _SwipeWarp ("Swipe Warp", Vector) = (1, 0, 0, 0)
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
            float _DirSwitch;
            float4 _SwipeOffset;
            float4 _SwipeWarp;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }
            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float2 repeatCell(float2 p, float2 cell, out float2 cellId)
            {
                cell = max(cell, 0.0001);
                float2 grid = p / cell + 0.5;
                cellId = floor(grid);
                return (frac(grid) - 0.5) * cell;
            }
                        
            /*
                Playing with iq's tiny torus shader
            */
            fixed4 frag(v2f IN) : SV_Target
            {
                //Camera depth
                float z = 5.;
                
                //Center and scale uvs
                float2 coord = (IN.vertex.xy - .5*_ScreenParams.xy)/_ScreenParams.y/.1;
                float2 swipeOffset = _SwipeOffset.xy;
                // return float4(coord/20, 0, 1);
                // coord = frac(coord/40) - 0.5;
                // coord / .025;
                float4 col = 0;
                //Raymarch loop (100 steps)
                for(int i = 0; i < 100; i++)
                {
                    //Raymarch sample point
                    float3 p = float3(coord,z);
                    float cellSize = 3.5;
                    float baseSpeed = cellSize * 0.09;

                    p.xy += swipeOffset * baseSpeed;

                    float rowId = floor(p.y / max(cellSize, 0.0001) + 0.5);
                    float rowDir = lerp(-1.0, 1.0, step(0.5, frac(rowId * 0.5)));
                    float rowSpeed = cellSize * lerp(0.04, 0.14, hash21(float2(rowId, 7.13)));
                    float colId = floor(p.x / max(cellSize, 0.0001) + 0.5);
                    float colDir = lerp(-1.0, 1.0, step(0.5, frac(colId * 0.5)));
                    float colSpeed = cellSize * lerp(0.04, 0.14, hash21(float2(colId, 7.13)));
                    p.x += swipeOffset.x * (rowDir * rowSpeed - baseSpeed) * saturate(_SwipeWarp.x);
                    p.y += swipeOffset.y * (colDir * colSpeed - baseSpeed) * saturate(_SwipeWarp.y);

                    float2 cellId;
                    p.xy = repeatCell(p.xy, float2(cellSize, cellSize), cellId);

                    float cellPhase = hash21(cellId) * 6.2831853;
                    float cellSpin = lerp(0.65, 1.35, hash21(cellId + 17.0));
                
                    //Rotated about y-axis
                    p.xz = mul(float2x2(cos(_Time.y * cellSpin + cellPhase + float4(0,33,11,0))), p.xz);

                    float majorRadius = 0.8;
                    float tubeRadius = 0.3;
                    //Outer ring radius
                    float d = length(p.xy)-majorRadius;
                    //Step the distance to torus
                    z -= d = .1+.2*abs(sqrt(d*d+p*p).z-tubeRadius);

                    float colorFreq = 2.0 / max(majorRadius, 0.001);
                    float prismPhase = p.y * colorFreq + z;
                    //Sample coloring (attenuate with distance)
                    col += (sin(prismPhase+float4(0,1,2,3))+1.0)/max(d, 0.0001);
                }
                //Tanh tonemap
                //https://mini.gmshaders.com/p/func-tanh
                col=tanh(col*col/1e5);
                return col;
            }
            ENDCG
        }
    }
}
