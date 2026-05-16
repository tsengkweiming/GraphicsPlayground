#ifndef __GLYPH_INCLUDED__
#define __GLYPH_INCLUDED__

#ifndef PI
#define PI 3.14159265359f
#endif
#ifndef TWO_PI
#define TWO_PI 6.2831853072
#endif


// https://math.stackexchange.com/questions/3020095/signed-angle-in-plane:
// "the ratio of the cross product and scalar product is the tangent of the angle"
// From [1]: "The tangent of the signed angle between a and b is det([ab]) / dot(ab)"
float signedAngle(float2 a, float2 b){
    // atan(y, x) returns the angle whose arctangent is y / x. Value in [-pi, pi]
    return atan2(a.x*b.y - a.y*b.x, dot(a, b));
}

float2 rotate2d(float2 v, float a){
    return mul(v, float2x2(cos(a),-sin(a), sin(a), cos(a)));
}

// https://www.shadertoy.com/view/4djSRW
float hash11(float p){
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float hash(float n) { return frac(sin(n) * 1e4); }

float3 rotateY(float3 p, float a)
{
    float s = sin(a);
    float c = cos(a);
    return float3(
        c * p.x + s * p.z,
        p.y,
       -s * p.x + c * p.z
    );
}
float2 project(float3 p)
{
    float d = 1.0; // camera distance
    return p.xy / (d - p.z);
}
float2 glyph3D(float2 p, float letterID)
{
    // lift to 3D
    float3 q = float3(p, 0.0);

    // random Y rotation
    float a = lerp(-0.8, 0.8, (letterID));
    q.x = rotate2d(q.xz, letterID).x;

    // project back to screen
    return q;//project(q);
}

// A helper to linearly interpolate between two points based on a sub-segment of time
float2 getLine(float2 start, float2 end, float t_segment) {
    return lerp(start, end, t_segment);
}

// Helper: Remaps t from range [t0, t1] to [0, 1]
// If t is outside the range, it clamps to the endpoints.
float2 segment(float t, float t0, float t1, float2 pStart, float2 pEnd) {
    float local_t = clamp((t - t0) / (t1 - t0), 0.0, 1.0);
    return lerp(pStart, pEnd, local_t);
}

// --- Letter A ---
// 3 Strokes: Up, Down, Crossbar
float2 getA(float t) {
    //float u = fract(t / (2.0 * PI)); // Normalize 0..1
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);

    float2 ln;
    if (u < 0.33) {
        // Left leg: (-0.5, -1) to (0, 1)
        float seg = u / 0.33; 
        ln = getLine(float2(-0.5, -1.0), float2(0.0, 1.0), seg);
    } else if (u < 0.66) {
        // Right leg: (0, 1) to (0.5, -1)
        float seg = (u - 0.33) / 0.33;
        ln = getLine(float2(0.0, 1.0), float2(0.5, -1.0), seg);
    } else if ( u < 0.75) {
        float seg = (u - 0.66) / 0.09;
        ln = getLine(float2(0.5, -1.0), float2(-0.25, -0.2), seg);
    } else {
        // Cross bar: (-0.25, -0.2) to (0.25, -0.2)
        float seg = (u - 0.75) / 0.25;
        ln = getLine(float2(-0.25, -0.2), float2(0.25, -0.2), seg);
    }
    
    // return rotate2d(ln, -0.31415 * 1);
    return ln;//glyph3D(ln, -3.1415 * u);
}

// --- Letter D ---
// 2 Strokes: Vertical Line, Semi-circle Arch
float2 getD(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);

    if (u < 0.3) {
        // Vertical spine
        float seg = u / 0.3;
        return getLine(float2(-0.5, -1.0), float2(-0.5, 1.0), seg);
    } else {
        // The curved belly
        float seg = (u - 0.3) / 0.7;
        // Map segment 0..1 to Angle PI/2 (90 deg) to -PI/2 (-90 deg)
        float angle = lerp(PI/2.0, -PI/2.0, seg);
        // Center is (-0.5, 0), Radius is 1.0 horizontal, 1.0 vertical
        return float2(-0.5, 0.0) + float2(1.1 * cos(angle), 1.0 * sin(angle));
    }
}

// --- Letter E ---
// 4 Strokes: Spine, Top, Bottom, Middle
float2 getE(float t, float2 bound) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    u = lerp(bound.x, bound.y, u);

    if (u < 0.25) {
        // Top Bar
        return getLine(float2(0.5, 1.0), float2(-0.5, 1.0), u / 0.25);
    } else if (u < 0.5) {
        // Vertical Spine (Top to Bottom)
        return getLine(float2(-0.5, 1.0), float2(-0.5, -1.0), (u - 0.25) / 0.25);
    } else if (u < 0.75) {
        // Bottom Bar
        return getLine(float2(-0.5, -1.0), float2(0.5, -1.0), (u - 0.5) / 0.25);
    } else {
        // Middle Bar (Slightly shorter)
        return getLine(float2(-0.5, 0.0), float2(0.2, 0.0), (u - 0.75) / 0.25);
    }
}

// --- Letter I ---
// 3 Strokes: Top Serif, Vertical, Bottom Serif
float2 getI(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.2) {
        // Top Serif
        return getLine(float2(-0.3, 1.0), float2(0.0, 1.0), u / 0.2);
    } else if (u < 0.8) {
        // Vertical Line
        return getLine(float2(0.0, 1.0), float2(0.0, -1.0), (u - 0.2) / 0.6);
    } else {
        // Bottom Serif
        return getLine(float2(0.0, -1.0), float2(0.3, -1.0), (u - 0.8) / 0.2);
    }
}

// --- Letter N ---
// Continuous 3 Strokes: Up, Diagonal Down, Up
float2 getN(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.33) {
        // Left Up
        return getLine(float2(-0.5, -1.0), float2(-0.5, 1.0), u / 0.33);
    } else if (u < 0.66) {
        // Diagonal Down
        return getLine(float2(-0.5, 1.0), float2(0.5, -1.0), (u - 0.33) / 0.33);
    } else {
        // Right Up
        return getLine(float2(0.5, -1.0), float2(0.5, 1.0), (u - 0.66) / 0.34);
    }
}

// --- Letter P ---
// 2 Strokes: Vertical, Upper Loop
float2 getP(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.4) {
        // Vertical Spine
        return getLine(float2(-0.5, -1.0), float2(-0.5, 1.0), u / 0.4);
    } else {
        // The Loop (Top half)
        float seg = (u - 0.4) / 0.6;
        float angle = lerp(PI/2.0, -PI/2.0, seg);
        // Center (-0.5, 0.5), Radius 0.5
        return float2(-0.5, 0.5) + float2(0.85 * cos(angle), 0.6 * sin(angle));
    }
}

// --- Letter R ---
// 3 Strokes: Vertical, Upper Loop, Diagonal Leg
float2 getR(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.3) {
        // Vertical Spine
        return getLine(float2(-0.5, -1.0), float2(-0.5, 1.0), u / 0.3);
    } else if (u < 0.7) {
        // The Loop
        float seg = (u - 0.3) / 0.4;
        float angle = lerp(PI/2.0, -PI/2.0, seg);
        return float2(-0.5, 0.5) + float2(0.85 * cos(angle), 0.6 * sin(angle));
    } else {
        // The Kick Leg
        float seg = (u - 0.7) / 0.3;
        return getLine(float2(-0.2, 0.0), float2(0.5, -1.0), seg);
    }
}

// --- Letter S ---
// 2 Strokes: Top Arc, Bottom Arc
float2 getS(float t, float2 bound)
{
    // normalize to 0..1 ping-pong (same style as P / R)
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    u = lerp(bound.x, bound.y, u);
    if (u < 0.5)
    {
        // Top curve (Top-Right → Center)
        float seg = u / 0.5;
        
        // Fix: End at 1.5 PI (270 deg) to touch the exact center (0,0)
        // Start roughly at 0.2 PI (approx 36 deg) for the top serif
        float angle = lerp(0.2 * PI, 1.5 * PI, seg);

        // Center is (0, 0.5), Radius is (0.6, 0.5)
        // At 1.5 PI: y = 0.5 + 0.5(-1) = 0.0. Matches center.
        return float2(0.0, 0.5) +
               float2(0.6 * cos(angle), 0.5 * sin(angle));
    }
    else
    {
        // Bottom curve (Center → Bottom-Left)
        float seg = (u - 0.5) / 0.5;

        // Fix: Start at 0.5 PI (90 deg) to match the center (0,0)
        // Go NEGATIVE (Clockwise) to sweep Right -> Bottom -> Left
        // End roughly at -0.9 PI for the bottom tail
        float angle = lerp(0.5 * PI, -0.9 * PI, seg);

        // Center is (0, -0.5), Radius is (0.6, 0.5)
        // At 0.5 PI: y = -0.5 + 0.5(1) = 0.0. Matches center.
        return float2(0.0, -0.5) +
               float2(0.6 * cos(angle), 0.5 * sin(angle));
    }
}

// --- Letter T ---
// 2 Strokes: Top Bar, Vertical
float2 getT(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.4) {
        // Top Bar
        return getLine(float2(-0.5, 1.0), float2(0.5, 1.0), u / 0.4);
    } else if (u < 0.6)
    {
        return getLine(float2(0.5, 1.0), float2(0.0, 1.0), (u - 0.4) / 0.2);
    }
    else {
        // Vertical Post
        // Note: This jumps from end of top bar (0.6, 1.0) to center (0.0, 1.0)
        return getLine(float2(0.0, 1.0), float2(0.0, -1.0), (u - 0.4) / 0.6);
    }
}
// --- Letter T ---
// Path: Left -> Center -> Down -> Center(retrace) -> Right
float2 getTDe(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);

    float2 pLeft = float2(-0.6, 1.0);
    float2 pCent = float2(0.0, 1.0);
    float2 pBot  = float2(0.0, -1.0);
    float2 pRight= float2(0.6, 1.0);

    if (u < 0.2) return segment(u, 0.0, 0.2, pLeft, pCent); // Top Left
    if (u < 0.5) return segment(u, 0.2, 0.5, pCent, pBot);  // Down
    if (u < 0.8) return segment(u, 0.5, 0.8, pBot, pCent);  // Up (Retrace)
    return       segment(u, 0.8, 1.0, pCent, pRight);       // Top Right
}

float2 getWW(float t)
{
    // Expand t so we get 2 zig-zags
    float u = t * 2.0;
    float tri_u = abs(frac(u / (2.0 * PI)) * 2.0 - 1.0);
    // x goes left → right → left → right
    float x = lerp(-0.5, 0.5, frac(u));

    // y does valley shapes
    float y = -0.5 + tri_u * 1.0;

    return float2(x, y);
}

// --- Letter W ---
// Continuous 4 Strokes: Down, Up, Down, Up
float2 getW(float t) {
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    if (u < 0.25) {
        return getLine(float2(-0.5, 1.0), float2(-0.3, -1.0), u / 0.25);
    } else if (u < 0.5) {
        return getLine(float2(-0.3, -1.0), float2(0.0, 0.0), (u - 0.25) / 0.25);
    } else if (u < 0.75) {
        return getLine(float2(0.0, 0.0), float2(0.3, -1.0), (u - 0.5) / 0.25);
    } else {
        return getLine(float2(0.3, -1.0), float2(0.5, 1.0), (u - 0.75) / 0.25);
    }
}
float2 getCircle(float t){
    return float2(sin(t), cos(t));
}

// http://mathworld.wolfram.com/Lemniscate.html
float2 getLemniscate(float t){
    float a = 1.5;
    return float2((a * cos(t)) / (1.0 + (sin(t) * sin(t))), 
                (a * sin(t) * cos(t))/ (1.0 + (sin(t) * sin(t))));
}

// http://mathworld.wolfram.com/HeartCurve.html
float2 getHeart(float t){
    return 0.05 * float2(1, -1) * float2(16.0 * sin(t) * sin(t) * sin(t),
                -(13.0 * cos(t) - 5.0 * cos(2.0 * t)
                - 2.0 * cos(3.0 * t) - cos(4.0 * t))) + float2(0, 0.1);
}


// https://en.wikipedia.org/wiki/Hypotrochoid
// https://mathworld.wolfram.com/Hypotrochoid.html
float2 getHypotrochoid(float t){
    float a = 5.0;
    float b = 3.0;
    float h = 5.0;
    float a_b  = a - b;
    float t_ab = t * a_b / b;
    return float2(a_b * cos(t) + h * cos(t_ab), a_b * sin(t) - h * sin(t_ab));
}

#define S(a) cc+=char(float(a)); tp.x-=FONT_SPACE;

// Converts a smooth sine wave (-1 to 1) into a sharp triangle wave (-1 to 1)
float smoothToSharp(float x) {
    return asin(sin(x)) / (PI / 2.0);
}
// --- Letter W ---
// Concept: A Lissajous curve. 
// X moves left-right slowly. Y bounces up-down 4 times faster.
float2 getWnew(float t) {
    // 1. Setup a time base that goes 0 -> 1 -> 0 (Retracing)
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    // 2. X Axis: Linear expansion width (-0.8 to 0.8)
    // Maps u(0..1) to x(-0.8..0.8)
    float x = (u * 2.0 - 1.0) * 0.8; 
    
    // 3. Y Axis: The 'W' shape is a high-frequency wave.
    // We want High -> Low -> High -> Low -> High
    // This is exactly cos(4 * PI * u)
    // We wrap it in smoothToSharp to make it pointy instead of curvy.
    float y = smoothToSharp(4.0 * PI * u);
    
    return float2(x, y);
}

// --- Letter N ---
// Concept: Y oscillates 3 times (Up, Down, Up).
// X waits, then moves, then waits (Clamped Ramp).
float2 getNnew(float t) {
    // 1. Time base: 0 -> 1 -> 0
    float u = abs(frac(t / (2.0 * PI)) * 2.0 - 1.0);
    
    // 2. X Axis: The diagonal logic.
    // N stays at x=-0.5 for the first 33%, moves to x=0.5, then stays.
    // We create a steep slope and clamp it.
    float x = clamp(3.0 * (u - 0.5), -0.5, 0.5);
    
    // 3. Y Axis: Up, Down, Up.
    // This is 1.5 cosine cycles: -1(start) -> 1(top) -> -1(bot) -> 1(end)
    // Formula: -cos(3 * PI * u)
    float y = -smoothToSharp(3.0 * PI * u);
    
    return float2(x, y);
}

// --- Helper Function for Dynamic Spacing ---
float getGap(float i, float t)
{
    float finalSpacing = 0.4; // Your original fixed spacing
    float slideDist = 2.5;    // How far to slide in from (the "gap" size)
    
    // 1. Stagger Logic
    // We slice the 1.0-0.0 range into segments for each letter.
    // i=0 runs from 1.0->0.7, i=1 runs from 0.85->0.55, etc.
    float duration = 0.4; // How long one letter takes to move
    float stagger = 1 - duration; // Delay between letters
    
    // Calculate start/end thresholds for this specific gap index
    float start = 1.0 - i * stagger;
    float end = start - duration;
    
    // Calculate progress 'p' (1.0 = Far Away, 0.0 = In Position)
    float p = smoothstep(end, start, t);
    
    // 2. "Rapidly when closer" Curve
    // pow(p, 0.5) creates a curve that drops FAST as it approaches 0.
    // This creates the magnetic "snap" effect at the end.
    float curvedP = pow(p, 0.5); 
    
    return slideDist * curvedP;
}

float sdCircle(float2 p, float r){
    return length(p) - r;
}

float sdBox(float2 p, float2 b){
    float2 d = abs(p) - b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdHeart(float2 p){
    p.x = abs(p.x);
    float a = atan2(p.x, p.y) / PI;
    float r = length(p);
    float h = abs(a);
    return r - (0.5 - 0.25*h);
}

float roseCurve(float2 uv, float time)
{
    // atan(uv.y, uv.x) have some artifact with fwidth
    float theta = uv.x > 0.0 ? atan(uv.y/uv.x) : atan(uv.y/uv.x) + PI;
    
    float i = 5.0, j = 6.0;

    float n = cos(0.003*i*time)*4.0+4.0;
    float d = sin(0.003*j*time)*4.0+4.0;
    
    float c = sin(time);//abs(iMouse.x/iResolution.x*2.0 - 1.0);		//using mouse to control "c"
    
    float r = 0.0;
    
    float factor = 0.0;
    for(int k=0; k < 5; k++)
    {
        r = (sin(n/d*theta))*0.5 + c;			//rose curve function
        float tmp = abs(length(uv) - r);
        factor += 1.0 - smoothstep(-1.5,1.5, tmp / fwidth(length(uv) - r));;
        theta += PI*2.0;
    }

    return theta;
}
#endif // __GLYPH_INCLUDED__