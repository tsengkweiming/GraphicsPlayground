Shader "Unlit/FolklorePlanetaire"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _TileCount ("Tile Count", Float) = 30
        _PatternCount("Pattern Count", Float) = 1
        _ColorLow("Color Low", Color) = (5., 0., 40.)
        _ColorMid1("Color Mid 1", Color) = (30., 80., 20.)
        _ColorMid2("Color Mid 2", Color) = (210., 20., 60.)
        _ColorHi("Color High", Color) = (210., 230., 0.)
        _TexWeight ("Texture Weight", Range(0,1)) = 0
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
            #define N_Pattern 5.

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
            float _TileCount;
            float _PatternCount;
            float3 _ColorLow;
            float3 _ColorMid1;
            float3 _ColorMid2;
            float3 _ColorHi;
            float _TexWeight;
            
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

            float sdCircle(float2 p, float r)
            {
                return length(p) - r;
            }

            float sdBox(float2 p, float2 b)
            {
                float2 d = abs(p) - b;
                return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
            }

            float sdDiamond(float2 p, float r)
            {
                return abs(p.x) + abs(p.y) - r;
            }

            float2 rotate2D(float2 p, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);

                return float2(
                    c * p.x - s * p.y,
                    s * p.x + c * p.y
                );
            }
            
            float3 make_cell(
                float2 tile_coord,
                float2 tile_idx,
                float3 background_noise)
            {
                float2 p = tile_coord;

                // Stable random values for this cell
                float2 rnd = hash(tile_idx);
                float rnd2 = hash(tile_idx + 13.27).x;
                float rnd3 = hash(tile_idx + 91.13).x;

                // --------------------------------
                // Per-cell transform
                // --------------------------------

                // 0 / 90 / 180 / 270 degree rotation
                float rotationIndex = floor(rnd.y * 4.0);
                float angle = rotationIndex * 3.14159265 * 0.5;

                p = rotate2D(p, angle);

                // Slight scale variation
                float scale = lerp(0.75, 1.25, rnd2);
                p *= scale;

                // --------------------------------
                // Choose a pattern
                // --------------------------------

                // float pattern = floor(rnd.x * _PatternCount);
                float structural = fmod(tile_idx.x + tile_idx.y, 3.0);

                float randomOffset =
                    floor(hash(floor(tile_idx / 4.0)).x * 3.0);

                float pattern = fmod(
                    structural + randomOffset,
                    _PatternCount
                );
                float d = 0.0;

                if (pattern < 1.0)
                {
                    // Circle
                    d = sdCircle(p, 0.28);
                }
                else if (pattern < 2.0)
                {
                    // Square
                    d = sdBox(p, float2(0.27, 0.27));
                }
                else if (pattern < 3.0)
                {
                    // Diamond
                    d = sdDiamond(p, 0.35);
                }
                else if (pattern < 4.0)
                {
                    // Ring
                    d = abs(sdCircle(p, 0.27)) - 0.06;
                }
                else if (pattern < 5.0)
                {
                    // Cross
                    float d1 = sdBox(p, float2(0.09, 0.32));
                    float d2 = sdBox(p, float2(0.32, 0.09));

                    d = min(d1, d2);
                }
                else
                {
                    // Four smaller dots
                    float2 q = abs(p) - 0.17;
                    d = sdCircle(q, 0.10);
                }

                float shape = 1.0 - smoothstep(
                    -0.015,
                     0.015,
                     d
                );

                // --------------------------------
                // Cell border
                // --------------------------------

                float border =
                    smoothstep(0.44, 0.48,
                        max(abs(tile_coord.x), abs(tile_coord.y)));

                float3 shapeColor = random_color(tile_idx);

                float3 color =
                    lerp(background_noise, shapeColor, shape);

                color *= 1.0 - border;

                return color;
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

            int GetIndex(float brightness, int numPatterns)
            {
                int safeCount = max(numPatterns, 1);
                int index = (int)floor(saturate(brightness) * safeCount);
                return clamp(index, 0, safeCount - 1);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Normalized pixel coordinates (from 0 to 1)
                // float2 uv = i.uv - 0.5;
                float2 uv = (2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y;

                float2 pos = float2(uv*6.0);

                float2 tile_coord = frac(uv*_TileCount)-.5;
                float2 tile_idx = floor(uv*_TileCount)-.5;
                
             
                // Use the noise function
                float reshape = 16.;
                
                float2 tmp = sin( float2(0.27+_Time.y/2000.,0.23)*_Time.y + .1*length(tile_idx)*float2(2.1,2.3))+tile_idx*.1;
                
                float n = fbm(tmp+fbm(tmp));

                half3 referenceColor = tex2D(_MainTex, saturate(i.uv)).rgb;
                float brightness = dot(referenceColor, float3(0.299, 0.587, 0.114));
                float patternIndex = lerp(n, GetIndex(brightness, _PatternCount)/_PatternCount , _TexWeight);//_SampleTex > 0 ? (GetIndex(brightness, _PatternCount)/_PatternCount + n) / 2. : n;

                float3 color_low = _ColorLow; //float3(5., 0., 40.);
                float3 color_mid1 = _ColorMid1; //float3(30., 80., 20.);
                float3 color_mid2 = _ColorMid2; //float3(210., 20., 60.);
                float3 color_high = _ColorHi; //float3(210., 230., 0.);
                
                float3 background_color = mix4ColorGradient(patternIndex, color_low, color_mid1, color_mid2, color_high);
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
