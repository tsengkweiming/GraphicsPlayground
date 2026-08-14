Shader "Unlit/Arrow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        // --- AXIS SWITCH & ANIMATION ---
        // 0 = Move X-axis (Arrow points LEFT)
        // 1 = Move Y-axis (Arrow points DOWN)
        [Toggle] _MoveAxis ("Move Axis", Float) = 0
        _Count ("Count", Vector) = (1.5, 1.0, 0, 0)
        _MotionSpeed ("Motion Speed", Float) = 0.5
        _HeadAngle ("Head Angle", Float) = 90
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
            float _MoveAxis;
            float2 _Count;
            float _MotionSpeed;
            float _HeadAngle;
            
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
                        
            float smin(float a, float b, float k)
            {
                float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }

            float sabs(float x, float k)
            {
                return sqrt(x*x + k*k);
            }

            float sdArrow(float2 p, float angleDegrees)
            {
                float r = 0.035;
                
                // Convert angle to half-angle slope
                float rad = radians(angleDegrees * 0.5);
                float slope = tan(rad);
                
                // arrow points LEFT
                float d1 = p.x - sabs(p.y, r) * slope;
                float d2 = 0.4 - p.x + sabs(p.y, r) * slope;

                // vertical size
                float d3 = abs(p.y) - 0.25;

                return max(smin(d1, d2, r), 0.);//d3
            }

            float mod(float x, float y)
            {
                return x - y * floor(x / y);
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // Normalized pixel coordinates (from -1 to 1)
                // float2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
                float2 uv = i.uv;//(2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y;

                float speed = _MotionSpeed; // Motion speed
                float offset = _Time.y * speed;

                if (_MoveAxis == 0) {
                    uv.x += offset; // Scroll horizontally
                } else {
                    uv.y += offset; // Scroll vertically
                    
                    // Rotate UV 90 degrees counter-clockwise 
                    // (Swaps axes: (x, y) -> (y, -x) so arrow points DOWN)
                    uv = float2(uv.y, -uv.x); 
                }
                // =========================================================

                // --- 1. CONTROL ARROW COUNT ---
                float2 count = _Count;
                uv *= count;

                // Grid domain repetition [-0.5, 0.5]
                uv = frac   (uv + 0.5) - 0.5;

                // Re-center arrow within its grid cell
                uv.x += 0.4;

                // --- 2. CONTROL ARROW HEAD ANGLE ---
                float headAngle = _HeadAngle; // Angle in degrees

                float d = sdArrow(uv, headAngle);

                // Antialiasing
                float aa = fwidth(d);
                float mask = 1.0 - smoothstep(-aa, aa, d);

                return mask;
            }
            ENDCG
        }
    }
}
