Shader "Hidden/CustomPostProcess/DiffusionBlur"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 200
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "PixelSort"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Fragment

            #include "Common/CustomPostProcessing.hlsl"

            sampler2D _PrevFrame;
            float4 _MainTex_TexelSize; // x = 1/width, y = 1/height

            float _DiffusionRate;
            float _ChromaOffset;
            
            // Sample RGB channels with a slight spatial offset for chromatic aberration
            half3 SampleChroma(sampler2D tex, float2 uv, float2 offset)
            {
                half r = tex2D(tex, uv + offset).r;
                half g = tex2D(tex, uv).g;
                half b = tex2D(tex, uv - offset).b;
                return half3(r, g, b);
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float2 texel = _MainTex_TexelSize.xy;
                float2 chromaOffsetVec = float2(_ChromaOffset, _ChromaOffset);
                half4 currentCol = GetSource(uv);

                // 2. Fetch neighbor samples from the previous frame (backbuffer)
                //    with chromatic aberration offset applied
                half3 prevUp    = SampleChroma(_PrevFrame, uv + float2(0.0,  texel.y), chromaOffsetVec);
                half3 prevDown  = SampleChroma(_PrevFrame, uv + float2(0.0, -texel.y), chromaOffsetVec);
                half3 prevLeft  = SampleChroma(_PrevFrame, uv + float2(-texel.x, 0.0), chromaOffsetVec);
                half3 prevRight = SampleChroma(_PrevFrame, uv + float2( texel.x, 0.0), chromaOffsetVec);

                // Neighbor average (u_neighbors) from previous frame
                half3 neighborAvg = (prevUp + prevDown + prevLeft + prevRight) * 0.25;

                // 3. Discrete Laplacian (∇²u) = (Neighbor Average) - (Current Value)
                half3 laplacian = neighborAvg - currentCol;

                // 4. Update equation: u(t+dt) = u(t) + a * ∇²u
                half3 result = currentCol + _DiffusionRate * laplacian;

                return float4(result, 1.0);
            }
            ENDHLSL
        }
    }
}
