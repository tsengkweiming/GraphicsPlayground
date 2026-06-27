#ifndef __SDF_INCLUDED__
#define __SDF_INCLUDED__

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

//SDF methods from IQ's website https://iquilezles.org/articles/distfunctions2d/

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

// ---------------------------------------------------------------------------
//  2D capsule SDF
// ---------------------------------------------------------------------------
float sdCap2D(float2 p, float2 a, float2 b, float r) {
    float2 pa = p - a, ba = b - a;
    float baLenSq = max(dot(ba, ba), 1e-6);
    return length(pa - ba * clamp(dot(pa, ba) / baLenSq, 0.0, 1.0)) - r;
}

// ---------------------------------------------------------------------------
//  2D oriented box SDF
//    center: world-space center of stick
//    angle:  rotation (radians)
//    half:   half-extents (40, 5) matching p5's rect(-40,-5,80,10)
// ---------------------------------------------------------------------------
float sdOBox(float2 p, float2 center, float angle, float2 halfOne) {
    float2  q = p - center;
    float c = cos(angle), s = sin(angle);
    q = float2(c*q.x + s*q.y, -s*q.x + c*q.y);  // rotate into local frame
    float2  d = abs(q) - halfOne;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdTriangle(in float2 p, in float2 p0, in float2 p1, in float2 p2)
{
    float2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    float2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    float2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    float2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    float2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    float2 d = min(min(float2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                        float2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                        float2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float sdParallelogram(in float2 p, in float width, in float height, in float skew)
{
	width *= 0.5;
	height *= 0.5;
	float2 e  = float2(skew,height);
	float e2 = skew * skew + height * height;
	
	p = (p.y < 0.0) ? -p : p;
	// horizontal edge
	float2 w = p - e;
	w.x -= clamp(w.x, -width, width);
	float2 d = float2(dot(w, w), -w.y);
	// vertical edge
	float s = p.x * e.y - p.y * e.x;
	p = (s < 0.0) ? -p : p;
	float2 v = p - float2(width, 0);
	v -= e * clamp(dot(v, e) / e2, -1.0, 1.0);
	d = min(d, float2(dot(v, v), width * height - abs(s)));
	return sqrt(d.x) * sign(-d.y);
}

float sdOrientedBox(in float2 p, in float2 s, in float2 e, float th)
{
    float l = length(e - s);
    float2 d = (e - s) / l;
    float2 q = (p - (s + e) * 0.5);
    q = mul(float2x2(d.x, d.y, -d.y, d.x), q);
    q = abs(q) - float2(l, th) * 0.5;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float sdEllipse(float2 p, float2 ab)
{
	// symmetry
	p = abs(p);

	// find root with Newton solver
	float2 q = ab * (p - ab);
	float w = (q.x < q.y) ? 1.570796327 : 0.0;
	for (int i = 0; i < 5; i++)
	{
		float2 cs = float2(cos(w), sin(w));
		float2 u = ab * float2(cs.x, cs.y);
		float2 v = ab * float2(-cs.y, cs.x);
		w = w + dot(p - u, v) / (dot(p - u, u) + dot(v, v));
	}
    
	// compute final point and distance
	float d = length(p - ab * float2(cos(w), sin(w)));
    
	// return signed distance
	return (dot(p / ab, p / ab) > 1.0) ? d : -d;
}

float sdPolygon(StructuredBuffer<float2> vertices, int vertexCount, in float2 p)
{
	if (vertexCount == 0) return 3.402823466e+38; // float max

	float d = dot(p - vertices[0], p - vertices[0]);
	float s = 1.0;

	for (int i = 0, j = vertexCount - 1; i < vertexCount; j = i, i++)
	{
		float2 e = vertices[j] - vertices[i];
		float2 w = p - vertices[i];
		float2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));

		bool3 c = bool3(p.y >= vertices[i].y, p.y < vertices[j].y, e.x * w.y > e.y * w.x);
		if ((c.x && c.y && c.z) || (!c.x && !c.y && !c.z)) s *= -1.0;
	}

	return s * sqrt(d);
}
 
#endif // __SDF_INCLUDED__
