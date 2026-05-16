Shader "Hidden/URP/VR/SpatialMapping/Wireframe"
{
    Properties
    {
        _WireThickness ("Wire Thickness", RANGE(0, 800)) = 100
        [Toggle] _FixedColorIndex ("FixedColorIndex", Float) = 0 
        _ColorIndex ("Color Index (int)", RANGE(0, 11)) = 0
        _ColorThickness ("Color Ramp Thickness", RANGE(0.05, 22.0)) = 0
        [Toggle] _MonoTone ("Mono Tone", Float) = 0
        _Tiling ("Tiling", Float) = 0 
        _Ripple ("Ripple", Float) = 0
        _Spiral ("Spiral", Float) = 0 
        _BeatsPerMinute ("BeatsPerMinute", Float) = 120
        _DotFactor ("DotFactor", RANGE(0.0, 1.0)) = 0
        _RippleFactor ("RippleFactor", RANGE(0.0, 1.0)) = 0 
        _SpiralFactor ("SpiralFactor", RANGE(0.0, 1.0)) = 0 
        _NoiseModeFactor ("NoiseModeFactor", RANGE(0.0, 1.0)) = 0 
        _NoiseIntensity ("NoiseIntensity", RANGE(0.0, 1.0)) = 0 
        _GlobalColorTone ("ColorTone(contra/gamma/bright/strength)", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "LightMode" = "UniversalForward"}
        LOD 100

        Pass
        {
            Name "Spatial Mapping Wireframe"
            Tags { "LightMode" = "UniversalForward" }

            // Wireframe shader based on the the following
            // http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

            HLSLPROGRAM
            #pragma require geometry

            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Common/Noise/SimplexNoise2D.cginc"

            float _WireThickness;
            float _MonoTone;
            float _ColorIndex;
            float _FixedColorIndex;
            float _ColorThickness;
            float4 _GlobalColorTone;
            float _Tiling;
            float _Spiral;
            float _Ripple;
            float _SpiralFactor;
            float _RippleFactor;
            float _DotFactor;
            float _NoiseModeFactor;
            float _NoiseIntensity;
            float _BeatsPerMinute; // Beats per minute

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g
            {
                float4 projectionSpaceVertex : SV_POSITION;
                float4 worldSpacePosition : TEXCOORD1;
                float2 uv : TEXCOORD0;
                float4 shadowCoord : TEXCOORD2;
                float3 normal : NORMAL;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(Attributes input)
            {
                v2g output = (v2g)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.projectionSpaceVertex = vertexInput.positionCS;
                output.worldSpacePosition = mul(UNITY_MATRIX_M, input.positionOS);
                output.uv = input.uv;
                output.normal = normalize(mul(input.normal, (float3x3)UNITY_MATRIX_I_M));

                // VertexPositionInputs vertexInputs = GetVertexPositionInputs(output.worldSpacePosition.xyz);
                // output.shadowCoord = GetShadowCoord(vertexInputs);
                // output.shadowCoord = TransformWorldToShadowCoord(output.worldSpacePosition.xyz);
                VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.shadowCoord = GetShadowCoord(vertexInput);
                return output;
            }

            struct g2f
            {
                float4 projectionSpaceVertex : SV_POSITION;
                float4 worldSpacePosition : TEXCOORD0;
                float4 dist : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                float3 normal : NORMAL;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            [maxvertexcount(3)]
            void geom(triangle v2g i[3], inout TriangleStream<g2f> triangleStream)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i[0]);

                float2 p0 = i[0].projectionSpaceVertex.xy / i[0].projectionSpaceVertex.w;
                float2 p1 = i[1].projectionSpaceVertex.xy / i[1].projectionSpaceVertex.w;
                float2 p2 = i[2].projectionSpaceVertex.xy / i[2].projectionSpaceVertex.w;

                float2 edge0 = p2 - p1;
                float2 edge1 = p2 - p0;
                float2 edge2 = p1 - p0;

                // To find the distance to the opposite edge, we take the
                // formula for finding the area of a triangle Area = Base/2 * Height,
                // and solve for the Height = (Area * 2)/Base.
                // We can get the area of a triangle by taking its cross product
                // divided by 2.  However we can avoid dividing our area/base by 2
                // since our cross product will already be double our area.
                float area = abs(edge1.x * edge2.y - edge1.y * edge2.x);
                float wireThickness = 800 - _WireThickness;

                g2f o;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.worldSpacePosition = i[0].worldSpacePosition;
                o.projectionSpaceVertex = i[0].projectionSpaceVertex;
                o.dist.xyz = float3( (area / length(edge0)), 0.0, 0.0) * o.projectionSpaceVertex.w * wireThickness;
                o.dist.w = 1.0 / o.projectionSpaceVertex.w;
                o.uv = i[0].uv;
                o.shadowCoord = i[0].shadowCoord;
                o.normal = i[0].normal;
                triangleStream.Append(o);

                o.worldSpacePosition = i[1].worldSpacePosition;
                o.projectionSpaceVertex = i[1].projectionSpaceVertex;
                o.dist.xyz = float3(0.0, (area / length(edge1)), 0.0) * o.projectionSpaceVertex.w * wireThickness;
                o.dist.w = 1.0 / o.projectionSpaceVertex.w;
                o.uv = i[1].uv;
                o.shadowCoord = i[1].shadowCoord;
                o.normal = i[1].normal;
                triangleStream.Append(o);

                o.worldSpacePosition = i[2].worldSpacePosition;
                o.projectionSpaceVertex = i[2].projectionSpaceVertex;
                o.dist.xyz = float3(0.0, 0.0, (area / length(edge2))) * o.projectionSpaceVertex.w * wireThickness;
                o.dist.w = 1.0 / o.projectionSpaceVertex.w;
                o.uv = i[2].uv;
                o.shadowCoord = i[2].shadowCoord;
                o.normal = i[2].normal;
                triangleStream.Append(o);
            }

            // Applies contrast, gamma, and brightness.
            // Clamp input 'c' before pow if it may be < 0.
            inline float3 ApplyTone(float3 color, float contrast, float gamma, float brightness)
            {
                // Avoid pow(0, gamma) issues,
                float3 safe_c = max(color, 0.0001);
                return contrast * pow(safe_c, gamma) + brightness;
            }

            // Overload to apply tone parameter (contrast, gamma, brightness)
            inline float3 ApplyTone(float3 color, float3 toneParams)
            {
                return ApplyTone(color, toneParams.x, toneParams.y, toneParams.z);
            }

            half4 frag(g2f i) : SV_Target
            {
                float minDistanceToEdge = min(i.dist[0], min(i.dist[1], i.dist[2])) * i.dist[3];

                // Early out if we know we are not on a line segment.
                if(minDistanceToEdge > 0.9)
                {
                    return half4(0,0,0,0);
                }

                float phase = _Time.y / (2 * 60.0/_BeatsPerMinute);
                float beatTime = frac(phase); // loops from 0 to 1 every beat
                float beatSin = sin(beatTime);
                float beatPulse = exp(-beatTime * 10.0); // sharp drop-off after beat
                float mirroredpPhase = abs(fmod(phase, 90.0) - 45.0);
                float2 uv = (i.uv * 2.0 - 1.0) * _Tiling; // controls tile scale

                // Smooth our line out
                float t0 = exp2(-2 * minDistanceToEdge * minDistanceToEdge);

                // dotish
                // float2 uv = i.uv * _Density; // control density
                // float2 gv = frac(uv) - 0.5;
                // float d = length(gv);
                // float t = smoothstep(0.25, 0.0, d);

                //Hexagonal Tile 
                // Beat-synced wavy movement
                float beatWobble = sin(beatTime * 6.2831853); // smooth loop 0~1~0
                float2 noiseOffset = float2(
                    sin(beatWobble * 3.14 + uv.y * 3.0) * 0.2,
                    cos(beatWobble * 3.14 + uv.x * 3.0) * 0.2
                );
                uv += lerp(noiseOffset, snoise(beatWobble), _NoiseModeFactor) * _NoiseIntensity;
                
                uv = float2(
                    uv.x * 2.0 / sqrt(3.0),
                    uv.y + (uv.x % 2.0) * 0.5
                );
                float2 gv = frac(uv) - 0.5;
                float d = length(gv);
                float t1 = smoothstep(0.4, 0.3, d);
                
                // Ripple 
                float r = length(uv);
                float t2 = abs(sin(r * _Ripple - _Time.y * 3.0));
                t2 = pow(t2, 3.0); // sharpen edges

                // Spiral
                float angle = atan2(uv.y, uv.x);
                float radius = length(uv);
                float t3 = sin(10.0 * radius - _Spiral * angle + phase * 12.0);

                float t = t1 * _DotFactor + t2 * _RippleFactor + t3 * _SpiralFactor;
                t = lerp(t, t0, saturate(1 - _DotFactor - _RippleFactor - _SpiralFactor));
                
                const half4 colors[11] = {
                        half4(1.0, 1.0, 1.0, 1.0),  // White
                        half4(1.0, 0.0, 0.0, 1.0),  // Red
                        half4(0.0, 1.0, 0.0, 1.0),  // Green
                        half4(0.0, 0.0, 1.0, 1.0),  // Blue
                        half4(1.0, 1.0, 0.0, 1.0),  // Yellow
                        half4(0.0, 1.0, 1.0, 1.0),  // Cyan/Aqua
                        half4(1.0, 0.0, 1.0, 1.0),  // Magenta
                        half4(0.5, 0.0, 0.0, 1.0),  // Maroon
                        half4(0.0, 0.5, 0.5, 1.0),  // Teal
                        half4(1.0, 0.65, 0.0, 1.0), // Orange
                        half4(1.0, 1.0, 1.0, 1.0)   // White
                    };

                float cameraToVertexDistance = length(_WorldSpaceCameraPos - i.worldSpacePosition.xyz) + mirroredpPhase;
                int index = _FixedColorIndex ? _ColorIndex : lerp(0, 10, cameraToVertexDistance) / _ColorThickness % 10;
                // index = (index + phase) % 10;
                half4 wireColor = colors[index];
                wireColor = _MonoTone > 0.0 ? step(dot(wireColor, 1.0), 2) : wireColor;

                wireColor.rgb = lerp(wireColor.rgb, ApplyTone(wireColor.rgb, _GlobalColorTone.xyz), _GlobalColorTone.w);
                half4 finalColor = lerp(float4(0,0,0,1), wireColor, t);
                finalColor.a = 1;

                Light mainLight = GetMainLight(i.shadowCoord);
                float NdotL = saturate(dot(normalize(_MainLightPosition.xyz), i.normal));
                float3 ambient = SampleSH(i.normal);
                finalColor.rgb *= NdotL * _MainLightColor.rgb * mainLight.shadowAttenuation + ambient;

                // Simple Shadow
                // float shadow = MainLightRealtimeShadow(i.shadowCoord);
                // return half4(1, 0, 0, 1) * shadow;
                // finalColor.rgb *= shadow;
                
                return finalColor;
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
