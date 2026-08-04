#ifndef __RANDOM_INCLUDED__
#define __RANDOM_INCLUDED__

#ifndef PI
#define PI 3.14159265359f
#endif

// Pseudo-random generator based on a seed
float random1to1(float seed) {
    return frac(sin(seed * 12.9898) * 43758.5453);
}

float hash(float n) { return frac(sin(n) * 1e4); }

float hash11(float p) {
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

// A deterministic 2D hash. Keeping the quad center as the seed means
// every pixel in a quad uses the same sample locations.
float2 hash22(float2 p)
{
    float n = sin(dot(p, float2(41.0, 289.0)));
    return frac(float2(262144.0, 32768.0) * n);
}

float hash2d(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * 0.13);
    p3 += dot(p3, p3.yzx + 3.333);
    return frac((p3.x + p3.y) * p3.z);
}

uint rand_hash(uint seed)
{
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;

	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;

	seed = seed ^ (seed >> 15);
	return seed;
}

// Wang Hash Random
#define UINT_MAX 4294967295
#define INV_UINT_MAX 2.3283064e-10

inline uint wang_hash(uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

float wang_hash01(uint seed)
{
    return wang_hash(seed) * INV_UINT_MAX;
}

float random(float t)
{
    return frac(sin(t * 12345.564) * 7658.76);
}

uint pcg(uint v)
{
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float pcg01(uint v)
{
    return pcg(v) / float(0xffffffffu);
}

// http://www.jcgt.org/published/0009/03/02/
uint3 pcg3d(uint3 v) {
    v = v * 1664525u + 1013904223u;

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;

    v ^= v >> 16u;

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;

    return v;
}

float3 pcg3df( float3 s ) {
    uint3 r = pcg3d( asuint( s ) );
    return float3( r ) / float( 0xffffffffu );
}

inline float random1dto1d(uint seed)
{
    return saturate(wang_hash(seed) * INV_UINT_MAX);
}

inline float random2dto1d(uint2 seed)
{
    return saturate(wang_hash(wang_hash(seed.x) ^ seed.y) * INV_UINT_MAX);
}
float2 random1dto2d(float x) {
    return float2(
        random1dto1d(x),
        random1dto1d(x + 17.0)
    );
}
inline float random3dto1d(uint3 seed)
{
    return saturate(wang_hash(wang_hash(wang_hash(seed.x) ^ seed.y) ^ seed.z) * INV_UINT_MAX);
}

float nrand(float2 co)
{
    return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
}

float nrand(float2 uv, float salt)
{
    uv += float2(salt, 0.0);
    return nrand(uv);
}

float3 nrand3(float2 seed)
{
    float t = sin(seed.x + seed.y * 1e3);
    return float3(frac(t * 1e4), frac(t * 1e6), frac(t * 1e5));
}

float3 random_orth(float2 seed)
{
	// float u = (nrand(seed) + 1.0) * 0.5;
    float u = nrand(seed);

    float3 axis;

    if (u < 0.166)
        axis = float3(0, 0, 1);
    else if (u < 0.332)
        axis = float3(0, 0, -1);
    else if (u < 0.498)
        axis = float3(0, 1, 0);
    else if (u < 0.664)
        axis = float3(0, -1, 0);
    else if (u < 0.83)
        axis = float3(-1, 0, 0);
    else
        axis = float3(1, 0, 0);

    return axis;
}

float3 random_positive_orth(float2 seed)
{
    float u = (nrand(seed) + 1) * 0.5;

    float3 axis;

    if (u < 0.333)
        axis = float3(0, 0, 1);
    else if (u < 0.666)
        axis = float3(0, 1, 0);
    else
        axis = float3(1, 0, 0);

    return axis;
}

// Uniformaly distributed points on a unit sphere
// http://mathworld.wolfram.com/SpherePointPicking.html
float3 random_point_on_sphere(float2 uv)
{
    float u = nrand(uv) * 2 - 1;
    float theta = nrand(uv + 0.333) * PI * 2;
    float u2 = sqrt(1 - u * u);
    return float3(u2 * cos(theta), u2 * sin(theta), u);
}

float rand(inout uint state, float max)
{
	return random1dto1d(state) * max;
}

#endif // __RANDOM_INCLUDED__
