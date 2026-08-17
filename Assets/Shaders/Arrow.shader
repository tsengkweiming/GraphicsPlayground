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
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                float3 normalOS : TEXCOORD2;
                UNITY_FOG_COORDS(3)
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
                o.positionOS = v.vertex.xyz;
                o.normalOS = v.normal;
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

            // Builds a continuous coordinate around the four vertical faces
            // of Unity's unit cube (local bounds: -0.5 to +0.5).
            // U runs +Z -> +X -> -Z -> -X, so it does not reset at the
            // front/side edges. V is the shared vertical coordinate.
            float2 cubeSurfaceUV(float3 positionOS, float3 normalOS)
            {
                float3 n = normalize(normalOS);
                float2 surfaceUV;
                float absX = abs(n.x);
                float absY = abs(n.y);
                float absZ = abs(n.z);

                if (absY > max(absX, absZ))
                {
                    // Top and bottom cannot both be part of one planar UV
                    // chart. Keep them stable with a local planar mapping.
                    surfaceUV = n.y > 0.0
                        ? float2(positionOS.x + 0.5, positionOS.z + 0.5)
                        : float2(positionOS.x + 0.5, 0.5 - positionOS.z);
                }
                else if (absZ >= absX)
                {
                    if (n.z > 0.0)
                    {
                        // Front (+Z), U = 0..1.
                        surfaceUV = float2(positionOS.x + 0.5, positionOS.y + 0.5);
                    }
                    else
                    {
                        // Back (-Z), U = 2..3.
                        surfaceUV = float2(2.5 - positionOS.x, positionOS.y + 0.5);
                    }
                }
                else if (n.x > 0.0)
                {
                    // Right (+X), U = 1..2.
                    surfaceUV = float2(1.5 - positionOS.z, positionOS.y + 0.5);
                }
                else
                {
                    // Left (-X), U = 3..4.
                    surfaceUV = float2(3.5 + positionOS.z, positionOS.y + 0.5);
                }

                return surfaceUV;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // Normalized pixel coordinates (from -1 to 1)
                // float2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
                float2 uv = cubeSurfaceUV(i.positionOS, i.normalOS);

                // Keep the animated coordinate on patternUV.x. In vertical
                // mode, swap the continuous height coordinate into X.
                float2 patternUV = (_MoveAxis == 0) ? uv : uv.yx;

                float speed = _MotionSpeed;
                float offset = _Time.y * speed;
                patternUV.x += offset;
                // =========================================================

                // --- 1. CONTROL ARROW COUNT ---
                float2 count = _Count;
                patternUV *= count;

                // Grid domain repetition [-0.5, 0.5]
                patternUV = frac(patternUV + 0.5) - 0.5;

                // Re-center arrow within its grid cell
                patternUV.x += 0.4;

                // --- 2. CONTROL ARROW HEAD ANGLE ---
                float headAngle = _HeadAngle; // Angle in degrees

                float d = sdArrow(patternUV, headAngle);

                // Antialiasing
                float aa = fwidth(d);
                float mask = 1.0 - smoothstep(-aa, aa, d);

                return mask;
            }
            ENDCG
        }
    }
}
