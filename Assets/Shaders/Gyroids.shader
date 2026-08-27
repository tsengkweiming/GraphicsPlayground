Shader "Unlit/Gyroids"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size ("Size", Float) = 1
        _PatternMode ("Pattern Mode", Range(0, 4)) = 0
        _ShapeBlend ("Shape Blend", Range(0, 1)) = 0.25
        _Scale ("Pattern Scale", Range(0, 12)) = 4
        _Warp ("Domain Warp", Range(0, 2)) = 0.65
        _Thickness ("Shell Thickness", Range(0.01, 0.35)) = 0.1
        _Twist ("Twist", Range(0, 3)) = 0.75
        _ColorMode ("Color Mode", Range(0, 4)) = 1
        _ColorFrequency ("Color Frequency", Range(0.05, 3)) = 1
        _ColorContrast ("Color Contrast", Range(0, 2)) = 1
        _VignetteStrength ("Vignette Strength", Range(0, 1)) = 1
        _Palette_A ("Palette_A", Vector) = (0.45, 0.45, 0.45, 0)
        _Palette_B ("Palette_B", Vector) = (0.35, 0.35, 0.35, 0)
        _Palette_C ("Palette_C", Vector) = (1, 1, 1, 1)
        _Palette_D ("Palette_D", Vector) = (0.7, 0.39, 0.2, 0)
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

            #ifndef CODEX_TWO_PI
            #define CODEX_TWO_PI 6.28318530718
            #endif

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
            float _PatternMode;
            float _ShapeBlend;
            float _Scale;
            float _Warp;
            float _Thickness;
            float _Twist;
            float _ColorMode;
            float _ColorFrequency;
            float _ColorContrast;
            float _VignetteStrength;
            float _MoveTime;
            float _Size;
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
                return a+b*cos(CODEX_TWO_PI*(c*t+d));
            }

            float modeWeight(float mode, float target)
            {
                return saturate(1.0 - abs(mode - target));
            }

            float3 rotateY(float3 p, float a)
            {
                float s = sin(a);
                float c = cos(a);
                return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
            }

            float3 foldOcta(float3 p)
            {
                return abs(p) - dot(abs(p), 0.333333);
            }

            float latticeShell(float v, float thickness)
            {
                return abs(v) / max(_Scale, 0.0001) - thickness;
            }

            // see https://www.youtube.com/watch?v=-adHIyjIYgk
            float gyroid(float3 p, float scale) {
                p *= scale;
                float bias = lerp(1.1, 2.65, sin(_Time.y*.4 + p.x/3. + p.z/4.)*.5+.5);
                // float g = latticeShell(dot(sin(p*1.01), cos(p.zxy*1.61)) - bias, _Thickness);
                float g = abs(dot(sin(p*1.01), cos(p.zxy*1.61)) - bias)/(scale*1.5)-.1;
                return g;
            }

            float schwarzP(float3 p, float scale)
            {
                p *= scale;
                float field = cos(p.x) + cos(p.y) + cos(p.z);
                return latticeShell(field, _Thickness * 1.25);
            }

            float diamond(float3 p, float scale)
            {
                p *= scale;
                float field = sin(p.x) * sin(p.y) * sin(p.z)
                            + sin(p.x) * cos(p.y) * cos(p.z)
                            + cos(p.x) * sin(p.y) * cos(p.z)
                            + cos(p.x) * cos(p.y) * sin(p.z);
                return latticeShell(field, _Thickness * 1.1);
            }

            float honeycomb(float3 p, float scale)
            {
                p *= scale;
                float invScale = 1.0 / max(scale, 0.0001);
                float3 q = abs(frac(p / CODEX_TWO_PI + 0.5) - 0.5) * CODEX_TWO_PI;
                float tubes = min(min(length(q.xy) - 1.1, length(q.yz) - 1.1), length(q.zx) - 1.1);
                float cells = max(max(abs(cos(p.x + p.y)), abs(cos(p.y + p.z))), abs(cos(p.z + p.x))) - 0.72;
                return lerp(tubes * invScale - _Thickness, cells * invScale - _Thickness, 0.45);
            }

            float foldedVoid(float3 p, float scale)
            {
                p *= scale;
                p = foldOcta(p + 0.45 * sin(p.zxy + _Time.y * 0.35));
                float field = dot(sin(p * 1.7), cos(p.yzx * 1.3));
                return latticeShell(field, _Thickness * 0.9);
            }

            float warpedScene(float3 p, float scale)
            {
                float time = _Time.y;
                float spin = _Twist * (0.35 * p.y + 0.15 * sin(time * 0.4));
                p = rotateY(p, spin);
                p += _Warp * 0.22 * sin(p.yzx * 2.1 + time * float3(0.55, 0.43, 0.37));

                float g = gyroid(p, scale);
                float sp = schwarzP(p + 0.4 * sin(time * 0.2), scale * 0.92);
                float dia = diamond(p + float3(0.35, -0.15, 0.2), scale * 0.82);
                float hex = honeycomb(p, scale * 0.72);
                float fold = foldedVoid(p, scale * 0.62);

                float mode = clamp(_PatternMode, 0.0, 4.0);
                float d = g * modeWeight(mode, 0.0)
                        + sp * modeWeight(mode, 1.0)
                        + dia * modeWeight(mode, 2.0)
                        + hex * modeWeight(mode, 3.0)
                        + fold * modeWeight(mode, 4.0);
                float hybrid = min(min(g, sp), min(dia, min(hex, fold)));
                return lerp(d, hybrid, _ShapeBlend);
            }

            float scene(float3 p) {
                // float g1 = .7*gyroid(p, 4.);
                // return g1;
                return warpedScene(p, max(_Scale, 0.0001));
            }

            float3 norm(float3 p) {
                float2 e = float2(0.01, 0.0);
                return normalize(float3(
                    scene(p + e.xyy) - scene(p - e.xyy),
                    scene(p + e.yxy) - scene(p - e.yxy),
                    scene(p + e.yyx) - scene(p - e.yyx)
                ));
                float3x3 k = float3x3(p,p,p) - 0.01;
                return normalize(scene(p) - float3(scene(k[0]),scene(k[1]),scene(k[2])));
            }

            float3 spectralColor(float t, float3 p, float3 n, float3 rd)
            {
                t = t * _ColorFrequency - _Time.y * 0.025;
                float3 iq = pal(t);
                float3 neon = 0.55 + 0.45 * cos(CODEX_TWO_PI * (t + float3(0.02, 0.34, 0.68)));
                float3 bands = lerp(float3(0.02, 0.06, 0.09), float3(1.0, 0.82, 0.25), smoothstep(0.25, 0.75, frac(t * 3.0 + p.y * 0.12)));
                float3 pearl = lerp(float3(0.08, 0.11, 0.16), float3(0.9, 0.95, 1.0), 0.5 + 0.5 * dot(n, normalize(float3(0.4, 0.7, -0.2))));
                float heatT = frac(t);
                float3 heat = float3(smoothstep(0.1, 0.9, heatT), smoothstep(0.25, 1.0, heatT * 0.8), smoothstep(0.75, 1.25, 1.0 - heatT));

                float mode = clamp(_ColorMode, 0.0, 4.0);
                float3 col = iq * modeWeight(mode, 0.0)
                           + neon * modeWeight(mode, 1.0)
                           + bands * modeWeight(mode, 2.0)
                           + pearl * modeWeight(mode, 3.0)
                           + heat * modeWeight(mode, 4.0);
                float rim = pow(saturate(1.0 - abs(dot(rd, n))), 2.0);
                col = lerp(0.5, col, _ColorContrast);
                return col + rim * 0.18;
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
                float2 uv = (IN.vertex.xy - 0.5 * _ScreenParams.xy) / _ScreenParams.y / _Size;
                float3 init = float3(_Time.y*_MoveTime,1.5,.3);
                float3 cam = normalize(float3(1., uv ));

                // basic raymarcher from @blackle
                float3 p = init;
                bool hit = false;
                for ( int i = 0; i < 100 && !hit; i++) {
                    if (distance(p,init) > 8.) break;
                    float d = scene(p);
                    // if (d*d < 0.00001) {
                    //     hit = true;
                    //     break;
                    // }
                    // p += cam * max(abs(d), 0.01);
                    if (d*d < 0.00001) hit = true;
                    p += cam*d;
                }
                float3 n = norm(p);

                float ao = 1.-smoothstep(-.3,.75,scene(p+n*.4))
                         * smoothstep(-3.,3.,scene(p+n*1.));
                
                float  fres = -max(0., pow(.8-abs(dot(cam,n)), 3.));
                float3 vign = smoothstep(0.,1.,1.-(length(uv*.8)-.1));
                float shapeBands = .1 + p.x*.28 + p.y*.2 + p.z*.2 + scene(p + n * 0.18) * 2.0;
                float3 col = spectralColor(shapeBands, p, n, cam);
                col = (fres+col)*ao;
                col = lerp(col, 0., !hit ? 1. : smoothstep(0.,8.,distance(p,init)));
                float vignetteMask = saturate(vign + 0.1);
                float vignetteAmount = lerp(1.0, vignetteMask, saturate(_VignetteStrength));
                col *= vignetteAmount;
                col = smoothstep(0.,1.+.3*sin(_Time.y+p.x*4.+p.z*4.),col);
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
