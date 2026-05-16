#ifndef PALETTE_INCLUDED
#define PALETTE_INCLUDED

#ifndef TWO_PI
#define TWO_PI 6.2831853072
#endif

// https://iquilezles.org/articles/palettes/
float3 getColour(float t, int palette, float elapsedTime){
    if(palette == 0){

        // Black and white
        return -0.5 * t + 0.45;
    }

    float3 a;
    float3 b;
    float3 c;
    float3 d;
    
    if(palette == 1){

        // Pastel rainbow
        // Animated

        t *= 0.45;
        t += 0.1 * elapsedTime;

        a = 0.65;
        b = 1.0 - a;
        c = float3(1.0,1.0,1.0);
        d = float3(0.15,0.5,0.75);

    }else if(palette == 2){

        // Red and purple

        t *= -0.3;
        t += 0.65;

        a = float3(0.55, 0.5, 0.7);
        b = 1.0-a;
        c = float3(1.0,1.0,1.0);
        d = float3(0.15,0.95,0.8);

    }else if(palette == 3){

        // Sofe Sage
        t *= 0.35;
        t += 0.3;

        a = float3(0.5, 0.55, 0.7);
        b = 1.0-a;
        c = float3(1.0,1.0,1.0);
        d = float3(0.4,0.8,0.3);
    }else if(palette == 4){

        // Blue
        // Same as above with different t

        t *= 0.35;
        t += 0.3;

        a = float3(0.55, 0.5, 0.7);
        b = 1.0-a;
        c = float3(1.0,1.0,1.0);
        d = float3(0.15,0.95,0.8);
    }

    return a + b * cos(TWO_PI * (c * t + d));
}

#endif // PALETTE_INCLUDED
