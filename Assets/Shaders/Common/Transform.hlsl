#ifndef __TRANSFORM_INCLUDED__
#define __TRANSFORM_INCLUDED__

float ConvertDegToRad(float degrees)
{
    return (3.141592 / 180.0) * degrees;
}

// 2D Rotation Matrix
float2x2 rotate2D(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

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
float3x3 RotateZ(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(  c, -s,  0.0,
                      s,  c,  0.0,
                      0.0, 0.0, 1.0);
}

float3x3 RotationMatrix(float3 radian)
{
    // float3 radian = float3(ConvertDegToRad(anglesDeg.x), ConvertDegToRad(anglesDeg.y), ConvertDegToRad(anglesDeg.z));

    float3x3 rotationX = RotateX(radian.x);

    float3x3 rotationY = RotateY(radian.y);

    float3x3 rotationZ = RotateZ(radian.z);

    // return mul(mul(rotationX, rotationY), rotationZ);
    return mul(mul(rotationZ, rotationY), rotationX);
}

float2 rotate2D(float2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

#endif // __TRANSFORM_INCLUDED__