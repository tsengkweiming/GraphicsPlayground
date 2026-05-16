#ifndef __SDFont_INCLUDED__
#define __SDFont_INCLUDED__

#ifndef PI
#define PI 3.14159265359f
#endif
#ifndef TWO_PI
#define TWO_PI 6.2831853072
#endif
#ifndef SQ2OV2
#define SQ2OV2 0.707106781187
#endif

float dot2( in float2 v ) { return dot(v,v); }

float sdSegment( in float2 p, in float2 a, in float2 b ){
    float2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

float sdTunnel( in float2 p, in float2 wh )
{
    p.x = abs(p.x); p.y = -p.y;
    float2 q = p - wh;

    float d1 = dot2(float2(max(q.x,0.0),q.y));
    q.x = (p.y>0.0) ? q.x : length(p)-wh.x;
    float d2 = dot2(float2(q.x,max(q.y,0.0)));
    float d = sqrt( min(d1,d2) );
    
    return (max(q.x,q.y)<0.0) ? -d : d;
}

float sdHalfCircle( in float2 p, in float r, in float rb )
{
    p.x = abs(p.x);
    return ((0.>p.y) ? length(float2(p.x-r, p.y)) : 
                                  abs(length(p)-r)) - rb;
}

float sdVerticalCapsule( float2 p, float h, float r ){
    p.y -= clamp( p.y, 0.0, h );
    return length( p ) - r; 
}

float sdRoundedBox( in float2 p, in float2 b, in float4 r ){
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    float2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

//sdf is wrong in the middle of the box if b.x>b.y
float sdHalfRoundedBox(in float2 p, in float2 b, in float2 r){
    r.x  = (p.y>0.0)?r.x  : r.y;
    p.x=abs(p.x);
    float2 q = p-b+r.x;
    return (p.y>0.)?
        abs(min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x):
        length(float2(abs(p.x)-b.x, p.y));
}

float sdArc( in float2 p, in float2 sc, in float ra, float rb )
{
    // sc is the sin/cos of the arc's aperture
    p.x = abs(p.x);
    return ((sc.y*p.x>sc.x*p.y) ? length(p-sc*ra) : 
                                  abs(length(p)-ra)) - rb;
}

//https://www.shadertoy.com/view/l3fcR7
float sdQuarterCircle( in float2 p, in float r, in float l, in float rb )
{
    return (.0>p.y||.0>p.x)?
        length(p-((p.x>p.y)?float2(r, -clamp(-p.y, 0., l)):float2(-clamp(-p.x, 0., l), r)))-rb:
        abs(length(p)-r) - rb;
}

// TODO : 
//    - start on special chars (so much work...)
float sdA(float2 p, float thickness){
    p.x = abs(p.x);
    const float4 long_bar = float4(0., .4, .175, -.3);
    const float height_of_middle_bar = .33;
    const float2 middle_bar = lerp(long_bar.zw, long_bar.xy, height_of_middle_bar);
    return min(
        sdSegment(p, long_bar.xy, long_bar.zw)-thickness,
        sdSegment(p, middle_bar, float2(0., middle_bar.y))-thickness);
}


float2 sdfGradA(float2 p, float thickness)
{
    float e = 0.001;
    return normalize(float2(
        sdA(p + float2(e,0), thickness) - sdA(p - float2(e,0), thickness),
        sdA(p + float2(0,e), thickness) - sdA(p - float2(0,e), thickness)
    ));
}

float sdB(float2 p, float thickness){
    p.y=-abs(p.y-.05);
    float2 tunnel_size = .175;
    p.y+=tunnel_size.x;
    p = p.yx;
    return abs(sdTunnel(p, tunnel_size))-thickness;
}

float sdC(float2 p, float thickness){
    p.y=abs(p.y-.05)-.175;
    return min(
        sdHalfCircle(p, .175, thickness), 
        sdVerticalCapsule(p+float2(.175, .175), .175, thickness));
}

float sdD(float2 p, float thickness){
    p.y-=clamp(p.y, .0-.13125, .35-.13125);
    return abs(sdTunnel(p.yx, .175))-thickness;
}

float sdE(float2 p, float thickness){
    p.y-=.05;
    p.y=abs(abs(p.y)-.175);
    return min(
            sdSegment(p, float2(.175, .175), float2(-.175, .175)),
            sdSegment(p, float2(-.175, 0.), float2(-.175, .175)))-thickness;
}

float2 sdfNormal(float2 p)
{
    float e = 0.001;
    float thickness = 0.001;
    return normalize(float2(
        sdA(p + float2(e,0), thickness) - sdA(p - float2(e,0), thickness),
        sdA(p + float2(0,e),thickness) - sdA(p - float2(0,e), thickness)
    ));
}

float2 tangent(float2 n)
{
    return float2(-n.y, n.x);
}

float2 projectToSDF(float2 p)
{
    float thickness = 0.001;
    float d = sdA(p, thickness);
    float2 n = sdfNormal(p);
    return p - n * d;   // 投影到 d = 0
}
float2 sdfTangent(float2 p)
{
    float2 n = sdfNormal(p);
    return float2(-n.y, n.x);
}
float2 stepAlongLetter(float2 p, float stepSize)
{
    p = projectToSDF(p);          // 先貼上去
    float2 t = sdfTangent(p);       // 算切線
    p += t * stepSize;            // 沿邊界走
    return p;
}
float2 projectToBand(float2 p, float band)
{
    float d = sdA(p, 0.01) - band;
    float2 n = sdfNormal(p);
    return p - n * d;
}
float2 warpFlow(float2 p, float t)
{
    float d = sdA(p, 0.01);
    float2 n = sdfNormal(p);
    float2 tg = tangent(n);

    float w = exp(-10.0 * abs(d));
    return tg * w * sin(t * 2.0);
}

float2 warpAttractor(float2 p, float strength)
{
    float d = sdA(p, 0.01);
    float2 n = sdfNormal(p);

    float falloff = exp(-8.0 * abs(d));
    return -n * falloff * strength;
}

float2 warpCarve(float2 p)
{
    float d = sdA(p, 0.01);
    float2 n = sdfNormal(p);

    return n * smoothstep(0.1, 0.0, abs(d)) * 0.03;
}
#endif // __SDFont_INCLUDED__