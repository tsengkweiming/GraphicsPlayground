Shader "Hidden/CustomPostProcess/MirrorEffect"
{
    SubShader
    {
        Tags { "RenderType"="Opaque"
               "RenderPipeline"="UniversalPipeline"
        }
        LOD 200
        ZWrite Off
        Cull off
        Pass
        {
            Name "MirrorEffectPass"
            
            HLSLPROGRAM
            #include "Common/CustomPostProcessing.hlsl"
            
            #pragma vertex Vert
            #pragma fragment frag
            
            float _Horizontal, _Vertical;
            float _Left, _Up;

            half4 frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;

                float x = uv.x, ix = 1.0 - uv.x;
                float sx = step(0.5, x);
                float y = uv.y, iy = 1.0 - uv.y;
                float sy = step(0.5, y);
                uv.x = lerp(lerp(x, ix, sx * _Horizontal), lerp(x, ix, (1.0 - sx) * _Horizontal), _Left);
                uv.y = lerp(lerp(y, iy, sy * _Vertical), lerp(y, iy, (1.0 - sy) * _Vertical), _Up);
                float4 color = GetSource(uv);
                return color;
            }
            ENDHLSL
        }
    }
}
