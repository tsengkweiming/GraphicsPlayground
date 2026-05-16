Shader "Hidden/Cloud2D"
{
    Properties
    {
        _CloudScale ("Cloud Scale", Float) = 1.1
        _Speed ("Speed", Float) = 0.03
        _CloudDark ("Cloud Dark", Float) = 0.5
        _CloudLight ("Cloud Light", Float) = 0.3
        _CloudCover ("Cloud Cover", Float) = 0.2
        _CloudAlpha ("Cloud Alpha", Float) = 8.0
        _SkyTint ("Sky Tint", Float) = 0.5
        _SkyColor1 ("Sky Color1", Color) = (0.2, 0.4, 0.6, 1)
        _SkyColor2 ("Sky Color2", Color) = (0.4, 0.7, 1, 1)
    }

    // シェーダーのコードが含まれる SubShader ブロック。
    SubShader
    {
        // SubShader Tags では SubShader ブロックまたはパスが実行されるタイミングと条件を
        // 定義します。
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend One One
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

            float _CloudScale;
            float _Speed;
            float _CloudDark;
            float _CloudLight;
            float _CloudCover;
            float _CloudAlpha;
            float _SkyTint;
            float4 _SkyColor1;
            float4 _SkyColor2;
            
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

            static const float2x2 cloudMatrix = float2x2(
                1.6,  1.2,
               -1.2,  1.6
            );

            float noise( in float2 p ) {
                const float K1 = 0.366025404; // (sqrt(3)-1)/2;
                const float K2 = 0.211324865; // (3-sqrt(3))/6;
	            float2 i = floor(p + (p.x+p.y)*K1);	
                float2 a = p - i + (i.x+i.y)*K2;
                float2 o = (a.x>a.y) ? float2(1.0,0.0) : float2(0.0,1.0); //float2 of = 0.5 + 0.5*float2(sign(a.x-a.y), sign(a.y-a.x));
                float2 b = a - o + K2;
	            float2 c = a - 1.0 + 2.0*K2;
                float3 h = max(0.5-float3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	            float3 n = h*h*h*h*float3( dot(a,hash2d(i+0.0)), dot(b,hash2d(i+o)), dot(c,hash2d(i+1.0)));
                return dot(n, float3(70.0,70.0,70.0));	
            }

            float fbm(float2 n) {
	            float total = 0.0, amplitude = 0.1;
	            for (int i = 0; i < 7; i++) {
		            total += noise(n) * amplitude;
		            n = mul(cloudMatrix, n);
		            amplitude *= 0.4;
	            }
	            return total;
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
                float2 uniformUV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                float asp = _ScaledScreenParams.x / _ScaledScreenParams.y;
                float2 uv = uniformUV * float2(asp, 1);
                float2 uv0 = uv;
                
                float bpm = 240.0 / 140.0;
                float alt = _Time.y / bpm;
                float time = _Time.y * _Speed;
                float q = fbm(uv * _CloudScale * 0.5);


                //ridged noise shape
	            float r = 0.0;
	            uv *= _CloudScale;
                uv -= q - time;
                float weight = 0.8;
                for (int i=0; i<8; i++){
		            r += abs(weight*noise( uv ));
                    uv = mul(cloudMatrix, uv) + time;
		            weight *= 0.7;
                }
                
                //noise shape
	            float f = 0.0;
                uv = uv0;
	            uv *= _CloudScale;
                uv -= q - time;
                weight = 0.7;
                for (int i=0; i<8; i++){
		            f += weight*noise( uv );
                    uv = mul(cloudMatrix, uv) + time;
		            weight *= 0.6;
                }
                
                f *= r + f;
                
                //noise colour
                float c = 0.0;
                time = _Time.y * _Speed * 2.0;
                uv = uv0;
	            uv *= _CloudScale*2.0;
                uv -= q - time;
                weight = 0.4;
                for (int i=0; i<7; i++){
		            c += weight*noise( uv );
                    uv = mul(cloudMatrix, uv) + time;
		            weight *= 0.6;
                }
                
                //noise ridge colour
                float c1 = 0.0;
                time = _Time.y * _Speed * 3.0;
                uv = uv0;
	            uv *= _CloudScale*3.0;
                uv -= q - time;
                weight = 0.4;
                for (int i=0; i<7; i++){
		            c1 += abs(weight*noise( uv ));
                    uv = mul(cloudMatrix, uv) + time;
		            weight *= 0.6;
                }
	            
                c += c1;
                
                float3 skycolour = lerp(_SkyColor2, _SkyColor1, uniformUV.y);
                float3 cloudcolour = float3(1.1, 1.1, 0.9) * clamp((_CloudDark + _CloudLight*c), 0.0, 1.0);
               
                f = _CloudCover + _CloudAlpha*f*r;
                
                float3 result = lerp(skycolour, clamp(_SkyTint * skycolour + cloudcolour, 0.0, 1.0), clamp(f + c, 0.0, 1.0));

                            
                // float4 tex = tex2D(_MainTex, uv);
                // col = lerp(col, tex, _FrameBlend);
                return float4(result, 1);
                
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