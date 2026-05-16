Shader "Hidden/ElevatorBuilding"
{
    Properties
    {
        _NeonLightAcc ("Neon Light Accumulation", Float) = 0.0
        _AmbientOcclusion ("Ambient Occlusion", Float) = 1.0
        _Texture ("Texture", 2D) = "white" {}
        _Speed ("Speed", Float) = 0.03
    }

    // シェーダーのコードが含まれる SubShader ブロック。
    SubShader
    {
        // SubShader Tags では SubShader ブロックまたはパスが実行されるタイミングと条件を
        // 定義します。
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend One Zero
            HLSLPROGRAM
            // この行では頂点シェーダーの名前を定義します。
            #pragma vertex vert
            // この行ではフラグメントシェーダーの名前を定義します。
            #pragma fragment frag

            // Core.hlsl ファイルには、よく使用される HLSL マクロおよび関数の
            // 定義が含まれ、その他の HLSL ファイル (Common.hlsl、
            // SpaceTransforms.hlsl など) への #include 参照も含まれています。
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // DeclareDepthTexture.hlsl ファイルにはカメラ深度テクスチャのサンプリング用の
            // ユーティリティが含まれています。
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float mod(float x, float y) {
                return x - y * floor(x / y);
            }

            #define LIGHTS_ON
            
            // 2D rotation
            #define rot(a) float2x2(cos(a), -sin(a), sin(a), cos(a))

            // Domain rep.
            #define rep(p, r) mod(p+r, r+r)-r

            // Domain rep. ID
            #define rid(p, r) floor((p+r)/(r+r))

            // Finite domain rep.
            #define lrep(p, r, l) p-r*clamp(round(p/r), -l, l)

            float _NeonLightAcc;
            float _accumulation;
            float _AmbientOcclusion;
            float _occlusion;
            sampler2D _Texture;
            float _Speed;
            
            // この例では、Attributes 構造体を頂点シェーダーの入力構造体として
            // 使用しています。
            struct Attributes
            {
                // positionOS 変数にはオブジェクト空間内での頂点位置が
                // 含まれます。
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                // この構造体内の位置には SV_POSITION セマンティックが必要です。
                float4 positionHCS  : SV_POSITION;
            };

            // Varyings 構造体内に定義されたプロパティを含む頂点シェーダーの
            // 定義。vert 関数の型は戻り値の型 (構造体) に一致させる
            // 必要があります。
            Varyings vert(Attributes IN)
            {
                // Varyings 構造体での出力オブジェクト (OUT) の宣言。
                Varyings OUT;
                // TransformObjectToHClip 関数は頂点位置をオブジェクト空間から
                // 同種のクリップスペースに変換します。
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                // 出力を返します。
                return OUT;
            }

            float3 hash(float3 x)
            {
                uint3 v = asuint(x);
                v = v * 1664525u + 1013904223u;
                v.x += v.y * v.z;
                v.y += v.z * v.x;
                v.z += v.x * v.y;
                v ^= (v >> 16);
                v.x += v.y * v.z;
                v.y += v.z * v.x;
                v.z += v.x * v.y;
                return (float3)(v) / 4294967295.0; // normalize using float(-1u)
            }
            
            float2 hash2d( float2 p ) {
	            p = float2(dot(p,float2(127.1,311.7)), dot(p,float2(269.5,183.3)));
	            return -1.0 + 2.0*frac(sin(p)*43758.5453123);
            }

            // Fast random noise 2 -> 3
            float3 hash3d(float2 p) {
                float2 r = frac(sin(mul(p,float2x2(137.1, 12.7, 74.7, 269.5))) * 43478.5453);
                return float3(r, frac(r.x*r.y*1121.67));
            }

            // Random noise 3 -> 3 - https://shadertoyunofficial.wordpress.com/2019/01/02/
            #define hash33(p) frac(sin(mul(p, float3x3(127.1,311.7,74.7,269.5,183.3,246.1,113.5,271.9,124.6)))*43758.5453123)

            // Distance functions - https://iquilezles.org/articles/distfunctions/
            float box(float3 p, float3 b) {
                float3 q = abs(p) - b;
                return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
            }
            float rect(float2 p, float2 b) {
                float2 d = abs(p) - b;
                return length(max(d, 0.)) + min(max(d.x, d.y), 0.);
            }

            #define ext 2.
            float opElevatorWindows(float3 p, float b) {
                float e  = box(p, float3(ext*.8, 2.7, .3));
                float lv = length(p.xz) - .1;   p.y += 1.;
                float lh = length(p.yz) - .1;
                lh = max(b, lh);
                b  = max(b, -e);
                b  = min(b, min(lv, lh));
                return b;
            }

            float building(float3 p0, float3 p, float L) {
                float B = rect(p.xz, float2(L, 10)); // Main building   
                float B2 = rect(float2(abs(p.x)-L-ext, p.z), float2(ext, 10)); // Elevator building
                
                // (Optim) Skip building calculations
                if (min(B, B2) > .2) return min(B, B2);
                
                float3 q = p;
                float var = step(1., mod(rid(p.y, 3.), 6.)); // Railing variation
                p.y = rep(p.y, 3.); // Infinite floor y-repetition
                float3 pb = float3(abs(p.x), p.yz);

                #ifdef LIGHTS_ON
                    // Building lights
                    float3  id = rid(float3(q.xy, p0.z), float3(21, 18, 48));
                    float3  rn = hash33(id);
                    float rw = frac(rn.x*rn.z*1021.67);
                        
                    q.x += 14. * (rn.x*3.-1.);
                    q.y += 12. * (floor(rn.y*3.)-1.);
                    q.xy = rep(q.xy, float2(21, 18));

                    float l = box(q, float3(lerp(3., 15., rw), rn.z*1.5+.5, 7));
                    _accumulation += .5 / (1. + pow(abs(l)*20., 1.5)) 
                                * smoothstep(0., .4, _Time.y - rw * 20.)
                                * step(p0.x, 10. + 2e2*step(20., abs(p0.z)));
                #endif
                
                // Occlusion
                _occlusion = min(_AmbientOcclusion, smoothstep(3.5, 0., -rect(p.xz, float2(L+2.,10))));    
                _occlusion = min(_occlusion, smoothstep(0.6, 0., -rect(pb.xz-float2(L+ext,0), float2(ext,10))));
                
                // Front hole
                q = p;
                q.x = rep(q.x, 7.);    
                q.y -= (1. - var)*1.01;
                
                float f = box(q + float3(0,0,10), float3(6.6, 2. + var, 3));
                B = max(B, -f);
                B = max(B, -rect(q.xz + float2(0,10), float2(6.6, .7)*var));
                
                // Railing
                q = p;
                q.x = rep(q.x, .8);
                
                float r  = length(p.yz + float2(1, 9.5-var*.5)) - .2;
                float rv = length(q.xz + float2(0, 9.5-var*.5)) - .16;
                r = min(r, rv);
                r = max(r, p.y + 1.);

                // Back bars
                q = p;
                q.x = rep(q.x, 1.75);
                
                float b = length(q.xz + float2(0, 7.3)) - .2;
                r = min(r, b);
                
                B = min(B, r);
                B = max(B, abs(p.x) - L);
                        
                // (Optim) Skip elevator calculations
                if (B2 > .04) return min(B, B2);
                
                // Elevator
                B2 = opElevatorWindows(pb - float3(L+ext,0,-9.9), B2);
                B2 = opElevatorWindows(float3(pb.z+8., pb.y, pb.x-L-ext-1.9), B2);

                // Side windows
                q = float3(pb.xy, pb.z - 1.8);
                q.z = lrep(q.z, 2.5, 2.);
                
                float w = box(q - float3(L+ext*2.,1.2,0), float3(.5, 1.6, 1.2));
                B2 = max(B2, -w);
                            
                return min(B, B2);
            }

            float map(float3 p) {
                float2 id = float2(step(40., p.x), rid(p.z, 140.));  
                float3 rn = lerp(float3(1, -.5, 0), hash3d(id), step(.5, id.x+id.y));
                    
                // Buildings
                float3 p0 = p;
                p.x = abs(abs(p.x - 40.) - 80.);
                p.z = rep(p.z - id.x*200., 200.);
                
                float bL = 21.4 + id.y*3.;
                float b1 = building(p0, p - float3(30,0,0), bL);
                float b2 = building(p0, float3(p.z,p.y,-p.x), 185.);
                
                // Elevator lights
                float rpy = 80. + 150. * rn.x;;
                p.y = rep(p.y - _Time.y * 40. * (rn.y*.5+.5), rpy);
                p -= float3(30.+bL+ext, rn.z*rpy*.5, ext-10.);

                float l = box(p, float3(ext*.8, 2.7, ext*.8));
                _accumulation += .5 / (1. + pow(abs(l)*18., 1.17));
                
                // Fix broken distance before 20s
                b2 = min(b2, abs(p0.x + p0.z - 30.) + 6.);

                return min(b1, b2);
            }

            // https://iquilezles.org/articles/normalsSDF/
            float3 normal(float3 p) {
                const float2 k = float2(1,-1)*.0001;
                return normalize(k.xyy*map(p + k.xyy) + k.yyx*map(p + k.yyx) + 
                                 k.yxy*map(p + k.yxy) + k.xxx*map(p + k.xxx));
            }

            // フラグメントシェーダーの定義。
            // Varyings 入力構造体には頂点シェーダーからの補間された値が
            // 含まれます。フラグメントシェーダーで `Varyings` 構造体の `positionHCS` プロパティを
            // 使用してピクセルの位置を取得しています。
            half4 frag(Varyings IN) : SV_Target
            {
                // 深度バッファのサンプリング用の UV 座標を算出するために
                // ピクセル位置をレンダーターゲットの解像度である
                // _ScaledScreenParams で除算します。
                float2 uv = IN.positionHCS.xy / _ScaledScreenParams.xy;
                uv = uv * 2.0 - 1.0;
                float2 resolution = _ScaledScreenParams.xy;
                float2 mousePosition = 0;
                
                float bpm = 240.0 / 140.0;
                float alt = _Time.y / bpm;
                float time = _Time.y * _Speed;

                // Camera animation
                float T  = 1. - pow(1. - clamp(_Time.y*.025, 0., 1.), 3.);
                float ax = lerp(-.8, .36, T);
                float az = lerp(-40., -140., T);
                float rx = mousePosition.x*.45 - (cos(_Time.y*.1)*.5+.5)*.4;
                rx = clamp(ax + rx - .55, min(_Time.y*.05 - 1.6, -.9), .1);   

                // Ray origin & direction
                float3 ro = float3(0, _Time.y*10., az);
                float3 rd = normalize(float3(uv, 3));
                
                rd.zy = mul(rd.zy, rot(mousePosition.y*1.3)); 
                rd.zx = mul(rd.zx, rot(rx)); 
                ro.zx = mul(ro.zx, rot(rx)); 
               
                // Raymarching
                float3 p; float d, t = 0.;
                for (int i = 0; i < 60; i++) {
                    p = ro + t * rd; 
                    t += d = map(p);
                    if (d < .01 || t > 2200.) break;
                }
                
                // Base color
                float3 col = float3(.13,.11,.26) - float3(1,1,0)*abs(p.x-40.)*.001;
                col *= clamp(1. + dot(normal(p), normalize(float3(0,0,1))), .5, 1.);
                
                // Texture
                col *= 1. - tex2D(_Texture, float2(p.x+p.z, p.y+p.z)*.05).rgb*.7;
                
                // Occlusion
                col *= _occlusion;
                
                // Exponential fog
                col = lerp(float3(.002,.005,.015), col, exp(-t*.0025*float3(.8,1,1.2) - length(uv)*.5));

                // Light accumulation
                col += _accumulation * lerp(float3(1,.97,.76), float3(1,.57,.36), t*.0006);
                       
                // Color correction
                col = pow(col, .46*float3(.98,.96,1));
                
                // Vignette
                uv = IN.positionHCS.xy / _ScaledScreenParams.xy; uv *= 1. - uv.yx;
                col *= pow(clamp(uv.x * uv.y * 80., 0., 1.), .2);
                               
                float4 result = float4(col, 1);
                // float4 tex = tex2D(_MainTex, uv);
                // col = lerp(col, tex, _FrameBlend);
                return result;
                
                return float4(uv,0,1);

                // カメラ深度テクスチャから深度をサンプリングします。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(uv);
                #else
                    // Z を OpenGL の NDC ([-1, 1]) に一致するよう調整
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

                // ワールド空間位置を再構成します。
                float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);

                // 以下の部分ではチェッカーボードエフェクトを作成します。
                // scale は正方形の逆サイズです。
                uint scale = 10;
                // 座標のスケーリング、ミラーリング、スナップを行います。
                uint3 worldIntPos = uint3(abs(worldPos.xyz * scale));
                // サーフェスを正方形に分割します。色の ID 値を計算します。
                bool white = ((worldIntPos.x) & 1) ^ (worldIntPos.y & 1) ^ (worldIntPos.z & 1);
                // ID 値 (black または white) に応じて正方形に色を塗ります。
                half4 color = white ? half4(1,1,1,1) : half4(0,0,0,1);

                // ファークリップ面の付近の色を黒に
                // 設定します。
                #if UNITY_REVERSED_Z
                    // D3D などの REVERSED_Z があるプラットフォームの場合。
                    if(depth < 0.0001)
                        return half4(0,0,0,1);
                #else
                    // Case for platforms without REVERSED_Z, such as OpenGL.
                    if(depth > 0.9999)
                        return half4(0,0,0,1);
                #endif

                return color;
            }
            ENDHLSL
        }
    }
}