Shader "Hidden/URPOctreeGrid_Sample"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Z ("Z", Float) = 0.2
        _Size ("Size", Float) = 1.0
        _CellCount ("Cell Count", Int) = 5
        _CellSize ("Cell Size", Vector) = (0.5, 0.5, 0.5)
    }

    // シェーダーのコードが含まれる SubShader ブロック。
    SubShader
    {
        // SubShader Tags では SubShader ブロックまたはパスが実行されるタイミングと条件を
        // 定義します。
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
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
            sampler2D _MainTex;
            float _Size;
            float _Z;
            int _CellCount;
            float3 _CellSize;

            uint3 pcg3d( uint3 s ) {
              s = s * 1145141919u + 1919810u;
              s.x += s.y * s.z;
              s.y += s.z * s.x;
              s.z += s.x * s.y;
              s ^= s >> 16;
              s.x += s.y * s.z;
              s.y += s.z * s.x;
              s.z += s.x * s.y;
              return s;
            }

            /**
             * pcg3d but float
             */
            float3 pcg3df( float3 s ) {
                uint3 r = pcg3d( asuint( s ) );
                return float3( r ) / float( 0xffffffffu );
            }

            /**
             * A function to generate a vec2 on a unit circle
             * Can be used for many purposes
             */
            float2 cis( float t ) {
                return float2( cos( t ), sin( t ) );
            }

            struct SubdivResult {
                float3 size;
                float3 cell;
                float3 hash;
            };

            /**
             * Return the grid cell information the given point belongs to.
             */
            SubdivResult subdivision( float3 p ) {
                SubdivResult result;

                // the initial size of a cell, it randomly halves
                result.size = _CellSize;//float3( 0.5, 0.5, 0.5 );

                for ( int i = 0; i < _CellCount; i ++ ) {
                    // where is the center of the cell?
                    result.cell = ( floor( p / result.size ) + 0.5 ) * result.size;

                    // calculate a random hash for each cell
                    result.hash = pcg3df( result.cell );

                    // should we subdiv more? (the condition uses the random hash)
                    if ( i == 4 || result.hash.x < 0.5 ) {
                      break; // no
                    } else {
                      result.size *= 0.5; // yeah, halve the size and do this again
                    }
                }

                return result;
            }

            struct GridResult {
                SubdivResult subdiv;
                float d;
            };

            /**
             * Return the grid cell information the ray currently belongs to
             * and a distance to the boundary of the cell.
             */
            GridResult gridTraversal( float3 ro, float3 rd ) {
                GridResult result;

                // get the info of the current grid cell
                // slightly pushing the ray position forward to see the next cell
                result.subdiv = subdivision( ro + rd * 1E-3 );

                // calculate the distance to the boundary
                // It's basically a backface only cube intersection
                // See the iq shader: https://www.shadertoy.com/view/ld23DV
                float3 src = -( ro - result.subdiv.cell ) / rd;
                float3 dst = abs( 0.5 * result.subdiv.size / rd );
                float3 bv = src + dst;
                result.d = min( min( bv.x, bv.y ), bv.z );

                return result;
            }
            
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

                float2 p = UV * 2.0 - 1.0;
                float2 asp = _ScaledScreenParams.x / _ScaledScreenParams.y;
                p.x *= asp;

                float z = _Z;//0.13;

                float3 col = float3( 0.0, 0.0, 0.0 );

                // fill the cell at the pixel
                {
                SubdivResult subdiv = subdivision( float3( p, z ) );
                //col = subdiv.hash;

                 col = tex2D( _MainTex, clamp(subdiv.hash.xy * UV * _Size, 0.,1.) ).rgb;

                }
                return float4(col, 1.0);

            
                float bpm = 240.0 / 140.0;
                float alt = _Time.y / bpm;
                //
                // float2 asp = _ScaledScreenParams.x / _ScaledScreenParams.y;
                //
                // float2 suv = (UV * 2.0 - 1.0) * asp;
                // float2 ruv = suv * 8.0;
                // float2 auv = abs(frac(ruv) - 0.5);
                //
                // float3 col = 0;
                //
                // if (hash(ceil(float3(ruv, alt * 16.0))).x < 0.1)
                // {
                //     if (any(auv < 0.02) && all(auv < 0.3))
                //         col += 1.0;
                // }
                //
                // col += step(abs(UV.y - 0.1), 0.03) *
                //        step(abs(UV.x - 0.5), 0.5 * frac(alt)) *
                //        step(frac(dot(float2(1, 1), suv) * 20.0 + 10.0 * alt), 0.5);
                //
                // return float4(col, 1);
            }
            ENDHLSL
        }
    }
}