Shader "GraphicsPlayground/Procedural/Torus Trail"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _RimColor("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower("Rim Power", Range(0.01, 10)) = 3
        _EmissionStrength("Emission Strength", Range(0, 10)) = 0.1
        _PulseSpeed("Pulse Speed", Float) = 0.1
        _PulseWidth("Pulse Width", Range(0.001, 1)) = 0.1
        _PulseIntensity("Pulse Intensity", Float) = 1
        _PulseSegmentPhase("Pulse Segment Phase", Float) = 0.16
        _PulseTrailPhase("Pulse Trail Phase", Float) = 0.002
        _PulseDarkBrightness("Pulse Dark Brightness", Range(0, 1)) = 0.15
        _PaletteWaveSpeed("Palette Wave Speed", Float) = 0.5
        _PaletteSegmentPhase("Palette Segment Phase", Float) = 0.75
        _PaletteTrailPhase("Palette Trail Phase", Float) = 0.001
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct VertexData
            {
                float3 position;
                float3 normal;
                float2 uv;
            };

            StructuredBuffer<int> _IndexBuffer;
            StructuredBuffer<VertexData> _VertexBuffer;
            StructuredBuffer<float4> _Palette;

            int _VerticesPerTrail;
            int _PaletteSize;

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _RimColor;
                float _RimPower;
                float _EmissionStrength;
                float _PulseSpeed;
                float _PulseWidth;
                float _PulseIntensity;
                float _PulseSegmentPhase;
                float _PulseTrailPhase;
                float _PulseDarkBrightness;
                float _PaletteWaveSpeed;
                float _PaletteSegmentPhase;
                float _PaletteTrailPhase;
                float3 _OffsetPosition;
                float4x4 _LocalToWorld;
            CBUFFER_END

            struct Attributes
            {
                uint vertexID : SV_VertexID;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 color : TEXCOORD2;
                float trailT : TEXCOORD3;
                float pulsePhase : TEXCOORD4;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                uint localIndex = _IndexBuffer[input.vertexID];
                uint bufferIndex = localIndex + input.instanceID * _VerticesPerTrail;
                VertexData vertex = _VertexBuffer[bufferIndex];
                vertex.position = mul(_LocalToWorld, float4(vertex.position, 1.0)).xyz;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(vertex.position);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = TransformObjectToWorldNormal(vertex.normal);
                output.trailT = vertex.uv.x;
                output.pulsePhase = input.instanceID * _PulseTrailPhase + vertex.uv.x * _PulseSegmentPhase;

                float paletteT = 0.5 + 0.5 * sin(
                    _Time.y * _PaletteWaveSpeed +
                    input.instanceID * _PaletteTrailPhase +
                    vertex.uv.x * _PaletteSegmentPhase);
                int paletteIndex = clamp((int)(paletteT * (_PaletteSize - 1)), 0, _PaletteSize - 1);
                output.color = _Palette[paletteIndex].rgb;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirection = normalize(GetWorldSpaceViewDir(input.positionWS));
                Light mainLight = GetMainLight();

                half diffuse = saturate(dot(normalWS, mainLight.direction));
                half3 halfVector = normalize(mainLight.direction + viewDirection);
                half specular = pow(saturate(dot(normalWS, halfVector)), 32);
                half rim = pow(1 - saturate(dot(normalWS, viewDirection)), _RimPower);

                // The original shader used the global segment index. Because
                // that index included the instance offset, every trail had a
                // different dark/bright phase. Reconstruct that behavior with
                // explicit local-segment and per-trail phase terms.
                float pulsePosition = frac(
                    input.pulsePhase +
                    _Time.y * _PulseSpeed);
                half brightBand = 1 - smoothstep(0, _PulseWidth, pulsePosition);
                half brightValue = 1.3 * _PulseIntensity;
                half brightness = lerp(_PulseDarkBrightness, brightValue, brightBand);

                half3 baseColor = input.color * _BaseColor.rgb * brightness;
                half3 directLight = mainLight.color * lerp(0.25, 1, diffuse);
                half3 emission = baseColor * _EmissionStrength;
                half3 rimLight = _RimColor.rgb * rim;
                half3 color = baseColor * directLight + emission + rimLight + specular * 0.15;

                color = MixFog(color, ComputeFogFactor(input.positionCS.z));
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
