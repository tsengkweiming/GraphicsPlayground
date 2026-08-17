Shader "Hidden/Pcx/URP Point Cloud"
{
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "PCX URP Point Cloud"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            StructuredBuffer<float4> _PointBuffer;

            CBUFFER_START(UnityPerMaterial)
                float4 _Tint;
                float4x4 _Transform;
                float _PointSize;
            CBUFFER_END

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
            };

            static const float2 kCorners[6] =
            {
                float2(-1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0),
                float2(-1.0, -1.0),
                float2( 1.0,  1.0),
                float2( 1.0, -1.0)
            };

            half3 DecodePcxColor(uint packedColor)
            {
                const half maxBrightness = 16.0h;
                half3 rgb = half3(
                    packedColor & 0xff,
                    (packedColor >> 8) & 0xff,
                    (packedColor >> 16) & 0xff);
                half brightness = (packedColor >> 24) & 0xff;
                return rgb * brightness * maxBrightness / (255.0h * 255.0h);
            }

            Varyings Vertex(Attributes input)
            {
                uint pointIndex = input.vertexID / 6;
                uint cornerIndex = input.vertexID - pointIndex * 6;
                float2 corner = kCorners[cornerIndex];
                float4 pt = _PointBuffer[pointIndex];
                float3 worldPosition = mul(_Transform, float4(pt.xyz, 1.0)).xyz;
                float4 origin = TransformWorldToHClip(worldPosition);
                float2 projectionScale = abs(UNITY_MATRIX_P._m00_m11);
                float2 extent = projectionScale * _PointSize;

                Varyings output;
                output.position = origin + float4(corner * extent, 0.0, 0.0);
                output.uv = corner;
                output.color = half4(DecodePcxColor(asuint(pt.w)) * _Tint.rgb, _Tint.a);
                return output;
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float radiusSquared = dot(input.uv, input.uv);
                clip(1.0 - radiusSquared);

                half edgeAlpha = saturate((1.0h - (half)radiusSquared) * 8.0h);
                return half4(input.color.rgb, input.color.a * edgeAlpha);
            }
            ENDHLSL
        }
    }
}
