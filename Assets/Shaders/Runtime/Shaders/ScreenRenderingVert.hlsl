#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDE_SCREEN_RENDERING
#define POSTEFFECT_GRAPH_HLSL_INCLUDE_SCREEN_RENDERING

#include "UnityCG.cginc"

// 画面やQuadにレンダリングする際のVertexShader

struct ScreenRenderingAttribute
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct ScreenRenderingVaryings
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
};

/**
 * \brief 画面やQuadにレンダリングする際のVertexShader
 */
ScreenRenderingVaryings ScreenRenderingVert(ScreenRenderingAttribute v)
{
    ScreenRenderingVaryings o;
    o.vertex = UnityObjectToClipPos(v.vertex.xyz);
    o.uv = v.uv;
    return o;
}
#endif