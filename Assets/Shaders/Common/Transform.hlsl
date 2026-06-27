#ifndef __TRANSFORM_INCLUDED__
#define __TRANSFORM_INCLUDED__

// ---------------------------------------------------------------------------
//  Rotation matrices 
// ---------------------------------------------------------------------------
float3x3 RotateX(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(1.0, 0.0, 0.0,
                    0.0,   c,  -s,
                    0.0,   s,   c);
}
float3x3 RotateY(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(  c, 0.0,   s,
                    0.0, 1.0, 0.0,
                     -s, 0.0,   c);
}

#endif // __TRANSFORM_INCLUDED__