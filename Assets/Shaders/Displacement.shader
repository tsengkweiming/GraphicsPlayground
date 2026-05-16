Shader "Custom/URP_Displacement"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        
        // Displacement Settings
        _Amplitude ("Wave Amplitude", Float) = 0.1
        _Frequency ("Wave Frequency", Float) = 2.0
        _Speed ("Wave Speed", Float) = 1.0
        
        _NoiseColor1 ("Noise Color 1", Color) = (0.445,0.732,1,1)
        _NoiseColor2 ("Noise Color 2", Color) = (1,0.4756,0.4756,1)
        _NoiseColor3 ("Noise Color 3", Color) = (0.097,0.623,0.388,1)
        
    }

    SubShader
    {
        // These tags are crucial for URP recognition
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Include URP Core libraries (Required for URP helper functions)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Common/Noise.hlsl"
            
            #define NOISE_FUNC(coord) snoise(coord)

            struct Attributes
            {
                float4 positionOS   : POSITION; // Object Space Position
                float3 normalOS     : NORMAL;   // Object Space Normal
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION; // Homogeneous Clip Space Position
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;   // World Space Normal (for lighting)
            };

            // Define Uniforms (Variables from Properties)
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _MainTex_ST;
                float _Frequency;
                float _Speed;
            CBUFFER_END

            float _GlobalTimeSec;
            float _TimeOffset;
            int _Seed;
            float3 _Scale;
            float3 _Direction;
            float4 _Size;
            float4 _Amplitude;
            float4 _Power;
            float4 _Gain;
            float3 _Offset;
            float4 _NoiseColor1;
            float4 _NoiseColor2;
            float4 _NoiseColor3;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            half FractalNoise(float3 uvw, float gamma, float intensity)
            {
                _Speed = 0.1;
                _Direction = float3(1,0,1);
                _Scale.xyz = float3(0.75, 3, 1.5);
                _Amplitude.xyzw = float4(1/2., 1, 2, 4);
                _Size.xyzw = float4(4,2,1,1/2.);
                _Power = 1;
                _Gain = 1;
                const float t = _Time.y * _Speed + _TimeOffset;
                const float3 xyz = uvw * _Scale + t * _Direction + _Offset;
		            
                // note: snoise() [-1,1]
                half4 noise4;
                noise4.x = _Amplitude.x * NOISE_FUNC(xyz * _Size.x + _Seed);
                noise4.y = _Amplitude.y * NOISE_FUNC(xyz * _Size.y + _Seed);
                noise4.z = _Amplitude.z * NOISE_FUNC(xyz * _Size.z + _Seed);
                noise4.w = _Amplitude.w * NOISE_FUNC(xyz * _Size.w + _Seed);
                noise4 = pow(0.5 * (noise4 + 1.0), _Power);
                noise4 = noise4 * 2.0 - 1.0;
                noise4 = noise4 * _Gain;
                float n = noise4.x + noise4.y + noise4.z + noise4.w;
                n /= dot(_Amplitude, _Gain);
                // n = n * 0.5 + 0.5;
                n = pow(n, gamma);
                // n = n * 2 - 1;
                // n = (n - _BlackLevel) / (_WhiteLevel - _BlackLevel);
                // n = saturate(n);
                // n = n < 0.5 ? pow(n * 2, _Contrast) * 0.5 : (1.0 - pow(2.0 * (1.0 - n), _Contrast) * 0.5);
                // n *= intensity;
                return n;
            }
            float limitZigZagMin(float val, float minVal)
            {
                // Formula: min + |val - min|
                return minVal + abs(val - minVal);
            }
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                // float3 displacedPos = IN.positionOS.xyz + (IN.normalOS * wave);
                float noise = FractalNoise(float3(IN.uv,0), 1, 0) * pow(1-saturate(IN.uv.y-0.4), 10);
                noise = limitZigZagMin(noise, 0);
                
                float3 tilt = 0;
                tilt.y = (IN.uv.y - 0.5) * 7 + noise * 12;
                float3 displace = tilt*3.6;
                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz) + displace;
                float4 clipPos = TransformWorldToHClip(worldPos);
                // --- 2. Standard URP Transformations ---
                // Convert the NEW displaced object position to World Space, then Clip Space
                // VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = clipPos;//vertexInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                half4 mask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // Simple normal pass-through (Real lighting would require recalculating normals)
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);
                OUT.normalWS = normalInput.normalWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                _Scale.xyz = float3(1, 2.3, 1);
                _Direction = float3(1,0,-0.8);
                _Seed = 1;
                float noise0 = FractalNoise(float3(IN.uv,0), 1, 0)*0.6+0.03;
                float4 noiseColor0 = noise0 * _NoiseColor1;
                
                _Scale.xyz = float3(0.72, 1, 1);
                _Direction = float3(1.5,0,-2);
                _Seed = 2;
                _TimeOffset = 10;
                float noise1 = FractalNoise(float3(IN.uv,0), 1, 0)*0.5+0.03;
                float4 noiseColor1 = noise1 * _NoiseColor2;
                
                _Scale.xyz = float3(1, 1, 1);
                _Direction = float3(1,0,-1);
                _Seed = 3;
                _TimeOffset = 3.7;
                float noise2 = FractalNoise(float3(IN.uv,0), 1, 0)*0.7 + 0.03;
                float4 noiseColor2 = noise2 * _NoiseColor3;

                float4 result = noiseColor0 + noiseColor1 + noiseColor2;
                // half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                return float4(result.xyz + _BaseColor,1);
            }
            ENDHLSL
        }
    }
}