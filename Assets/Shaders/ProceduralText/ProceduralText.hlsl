#ifndef __PROCEDURAL_TEXT_INCLUDED__
#define __PROCEDURAL_TEXT_INCLUDED__

struct Dot2d
{
    float2 position;
    float curvature;       // 0: straight, > 0: curvature
    int startOfNext;
    float4 color;
};

struct Character
{
    Dot2d  dots[];
    int    id;        // order id of the text
    float3 position;  // do some boid?
    float3 velocity;
    float3 scale;
};

struct Text
{
    Character  characters[];
    float3 position;
    float3 velocity;
};

//for chinese character maybe use sdf to form the field and use particle?

#endif // __PROCEDURAL_TEXT_INCLUDED__