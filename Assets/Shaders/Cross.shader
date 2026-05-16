Shader "Hidden/Cross"
{
    Properties
    { }

    // シェーダーのコードが含まれる SubShader ブロック。
    SubShader
    {
        // SubShader Tags では SubShader ブロックまたはパスが実行されるタイミングと条件を
        // 定義します。
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
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
            
            // フラグメントシェーダーの定義。
            // Varyings 入力構造体には頂点シェーダーからの補間された値が
            // 含まれます。フラグメントシェーダーで `Varyings` 構造体の `positionHCS` プロパティを
            // 使用してピクセルの位置を取得しています。
            half4 frag(Varyings IN) : SV_Target
            {
                // 深度バッファのサンプリング用の UV 座標を算出するために
                // ピクセル位置をレンダーターゲットの解像度である
                // _ScaledScreenParams で除算します。
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;

                float bpm = 240.0 / 140.0;
                float alt = _Time.y / bpm;

                float2 asp = _ScaledScreenParams.x / _ScaledScreenParams.y;

                float2 suv = (UV * 2.0 - 1.0) * asp;
                float2 ruv = suv * 8.0;
                float2 auv = abs(frac(ruv) - 0.5);

                float3 col = 0;

                if (hash(ceil(float3(ruv, alt * 16.0))).x < 0.1)
                {
                    if (any(auv < 0.02) && all(auv < 0.3))
                        col += 1.0;
                }

                col += step(abs(UV.y - 0.1), 0.03) *
                       step(abs(UV.x - 0.5), 0.5 * frac(alt)) *
                       step(frac(dot(float2(1, 1), suv) * 20.0 + 10.0 * alt), 0.5);

                // float4 tex = tex2D(_MainTex, uv);
                // col = lerp(col, tex, _FrameBlend);
                return float4(col, 1);
                
                return float4(UV,0,1);

                // カメラ深度テクスチャから深度をサンプリングします。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Z を OpenGL の NDC ([-1, 1]) に一致するよう調整
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

                // ワールド空間位置を再構成します。
                float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);

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