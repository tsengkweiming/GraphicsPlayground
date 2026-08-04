#ifndef PATTERN_INCLUDED
#define PATTERN_INCLUDED
#include <HLSLSupport.cginc>

float pattern_line(float2 uv, float2 range)
{
    return step(range.x, uv.x) * step(range.y, 1.0-uv.x);
}

float pattern_radius(float2 uv, float radius)
{
    // fixed radius = 0.4;
    fixed r = distance(uv, fixed2(0.5,0.5));
    return step(radius, r);
}

float pattern_circle(float2 uv, float num, float t)
{
    fixed len = distance(uv, fixed2(0.5,0.5)) + t;
    return step(0.9, sin(len*num));
}

float pattern_stripe(float2 uv, float num, float t)
{
    return step(0, sin(50*uv.x));
}

float pattern_grid(float2 uv, float num, float t)
{
    fixed2 v = step(0,sin(50*uv))*0.5;
    return frac(v.x+v.y)*2;
}

float pattern_rect(float2 uv, float num, float t)
{
    fixed2 size = fixed2(0.3,0.1);
    fixed2 leftbottom = fixed2(0.5,0.5) - size * 0.5;
    fixed2 uv1 = step(leftbottom, uv);
    uv1 *= step(leftbottom, 1-uv1);
    return uv1.x*uv1.y;
}

float pattern_circles(float2 uv, float num)
{
    fixed2 st = uv * num;
    st = frac(st);

    // 円の描画
    fixed l = distance(st,fixed2(0.5,0.5));
    return step(0.35, l);
}


#endif
