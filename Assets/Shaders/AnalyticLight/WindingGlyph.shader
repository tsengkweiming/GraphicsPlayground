Shader "Unlit/WindingGlyph"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Header(UV)]
        _AspectScale ("Aspect Scale 0:square/1:skew", Float) = 0
        _RotateScale ("Rotate Scale :1", Range(0, 10)) = 0
        _Flip ("Flip(norm:-1/flip:1/rnd:0)", Range(-1, 1)) = -1
        _GridSize ("GridSize", Range(1, 10)) = 1
        [Header(Letter)]
        _LetterScale ("Letter Scale", Range(-50,50)) = 4
        _LetterSegment ("Letter Segment", Range(0,80)) = 16
        _LetterSpeed ("Letter Speed", Float) = 0.5
        _LetterSeed ("Letter Seed", Int) = 0
        _Spacing ("Spacing", Range(0, 1)) = 0.4
        _SpacingSlideIn ("SpacingSlideIn", Range(0, 1)) = 1
        [IntRange] _SceneIndex ("SceneSelection", Range(1, 4)) = 1
        [IntRange] _PaletteIndex ("PaletteSelection 0:BW/1:Rainbow", Range(0, 5)) = 0
        // [KeywordEnum(One, Two, Three, Auto)] _Scene ("Scene Mode", Float) = 0
        [Header(Octree)]
        _CellSize ("CellStartSize", Range(-10, 10)) = 0.5
        _SubDivision ("SubDiv Iteration", Range(1, 10)) = 5
        _BorderColor ("BorderColor", Color) = (1,1,1,1)
        _SlideSpeed ("SlideSpeed 0.2(Try 0)", Range(-10, 10)) = 0.3
        _GridTileScale ("GridTile Scale", Range(0, 1)) = 0
        _WhiteGridSizeThreshold ("WGridSizeThresh 0.2", Range(0, 1)) = 0.2
        _WhiteGridRate ("WGridRate", Range(0, 1)) = 0.05
        _BorderRate ("BorderRate", Range(0, 1)) = 0
        _Z2 ("Z2", Float) = 0
        _Size ("Size", Vector) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile _SCENE_ONE _SCENE_TWO _SCENE_THREE _SCENE_AUTO
            #include "UnityCG.cginc"
            #include "../Common/Glyph.hlsl"
            #include "../Common/Palette.hlsl"
            #include "../Common/SDFont.hlsl"
            #include "../Common/Noise.hlsl"
            #include "../Common/Random.hlsl"

            // #define SCENE 2
            // #define PALETTE 2

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float mod(float x, float y)
            {
                return x - y * floor(x / y);
            }

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float sceneSwitchSpeed = 0.21;
            int _GridSize;
            float _BorderRate;
            float _Z2;
            float3 _Size;
            float4 _BorderColor;
            float _SlideSpeed;
            float _AspectScale;
            float _RotateScale;
            float _GridTileScale;
            float _WhiteGridRate;
            float _WhiteGridSizeThreshold;
            float _Flip;
            int _SceneIndex;
            int _PaletteIndex;
            float _LetterSegment;
            float _LetterSpeed;
            float _LetterScale;
            int _LetterSeed;
            float _CellSize;
            float _SubDivision;
            float2 letterBound;
            float _Spacing;
            float _SpacingSlideIn;

            float2 getWarpedPosition(float t)
            {
                float2 p = getLemniscate(t)/2.;

                for(int i = 0; i < 1; i++)
                {
                    //p += warpAttractor(p, 0.2);
                    //p += warpFlow(p, _Time.y);
                    //p += warpCarve(p);
                    p = stepAlongLetter(p, 0.0015);
                    // p = projectToBand(p, sin(_Time.y)*0.02);
                    // p += sdfTangent(p) * 0.01;
                    //p = integrate(p, .2);
                }

                return p;
            }

            float windingA(float2 p)
            {
                float a = 0.0;

                float2 a0 = float2(0.0,  0.4);
                float2 a1 = float2(0.175,-0.3);

                float midY = 0.33;
                float2 m0 = lerp(a1, a0, midY);
                float2 m1 = float2(0.0, m0.y);

                a += signedAngle(a0 - p, a1 - p);
                a += signedAngle(m0 - p, m1 - p);

                return a / TWO_PI;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #define CURVE_T 0
            #define CURVE_A 1
            #define CURVE_I 2
            #define CURVE_W 3
            #define CURVE_N 4
            #define CURVE_P 5
            #define CURVE_R 6
            #define CURVE_D 7
            #define CURVE_S 8
            #define CURVE_E 9

            struct SubdivResult {
                float3 size;
                float3 cell;
                float3 hash;
                int i;
                float d;
            };

            float2 evalCurve(int curveId, float t)
            {
                switch (curveId)
                {
                    case CURVE_T: return getT(t);
                    case CURVE_A: return getA(t);
                    case CURVE_I: return getI(t);
                    case CURVE_W: return getW(t);
                    case CURVE_N: return getN(t);

                    case CURVE_P: return getP(t);
                    case CURVE_R: return getR(t);
                    case CURVE_D: return getD(t);
                    case CURVE_S: return getS(t, letterBound);
                    case CURVE_E: return getE(t, letterBound);
                    
                    default: return 0;
                }
            }

            float drawTest(float2 uv, float radius, float segments, float t, float delta)
            {
                float angle = 0;
                [unroll(50)]
                for (float i = 0; i < segments/2; i += 1.)
                {
                    float ti0 = t + i * delta;
                    float ti1 = t + (i + 1.0) * delta;

                    float2 c0 = radius * roseCurve(uv, ti0);
                    float2 c1 = radius * evalCurve(uv, ti1);

                    angle += signedAngle(c0 - uv, c1 - uv);
                }
                return angle;
            }
            float draw(float2 uv, int curveId, float radius, float segments, float t, float delta)
            {
                float angle = 0;
                for (float i = 0; i < segments; i += 1.)
                {
                    float ti0 = t + i * delta;
                    float ti1 = t + (i + 1.0) * delta;

                    float2 c0 = radius * evalCurve(curveId, ti0);
                    float2 c1 = radius * evalCurve(curveId, ti1);

                    angle += signedAngle(c0 - uv, c1 - uv);
                }
                return angle;
            }
            float2 octree(float2 uv)
            {
                // Total iterations: How deep can the octree go?
                // 4 iterations = 1 -> 2 -> 4 -> 8 -> 16 subdivisions
                int iterations = 4;
                
                float2 currentUV = uv;
                float currentGridSize = _GridSize;
                float2 finalCellID = floor(uv * _GridSize);
                
                // Iterate to find the smallest sub-grid for this pixel
                for(int i = 0; i < iterations; i++)
                {
                    // 1. Calculate ID for the current level
                    float2 cellID = floor(currentUV * currentGridSize);
                    
                    // 2. Get random value for this specific cell
                    // We add 'i' to the seed so level 1 randomness differs from level 2
                    float rnd = snoise(cellID + float(i) * 13.52);
                    
                    // 3. The "Split" Chance
                    // If rnd > 0.5, we stop here (this is our leaf node).
                    // If rnd < 0.5, we continue to the next iteration (subdivide further).
                    if (rnd > 0.5) 
                    {
                        // We found our level! Save ID and break.
                        finalCellID = cellID;
                        break;
                    }
                    
                    // 4. If we didn't break, we subdivide:
                    // Increase grid density for the next pass
                    currentGridSize *= 2.0;
                }
                return currentGridSize;
            }
            float2 RotateGrid(float2 uv)
            {
                // --- Step 1: Grid Coordinates ---
                float2 scaledUV = uv * _GridSize;
                
                // The "Integer" part identifies which cell we are in (0, 1, 2...)
                float2 cellID = floor(scaledUV);
                
                // The "Fractional" part is the UV 0-1 range inside the cell
                float2 cellUV = frac(scaledUV);

                // --- Step 2: Randomness & Thresholding ---
                // Get a random value (0.0 to 1.0) specific to this cell
                float rnd = snoise(cellID) * 2 + 1;

                // Only apply rotation to 10% of the cells
                if (rnd < 0.1) 
                {
                    // --- Step 3: Determine Rotation Angle ---
                    // We re-use 'rnd' to pick an angle. 
                    // We map the 0.0-0.1 range to indices 1, 2, or 3.
                    // 1 = 90 deg, 2 = 180 deg, 3 = 270 (-90) deg.
                    // (We skip 0 because that's the default unrotated state)
                    
                    float variation = floor(frac(rnd * 100.0) * 3.0) + 1.0;
                    
                    // Convert to radians (90 degrees = PI/2)
                    float angle = variation * 1.57079633; // 1.5707... is PI/2

                    // --- Step 4: Rotate around Center ---
                    // Standard 2D Rotation Matrix logic
                    float s = sin(angle);
                    float c = cos(angle);
                    
                    // 1. Move pivot to center (0.5, 0.5)
                    cellUV -= 0.5;
                    
                    // 2. Rotate
                    // To implement 90/-90/180/-180, this matrix works perfectly
                    cellUV = float2(
                        cellUV.x * c - cellUV.y * s,
                        cellUV.x * s + cellUV.y * c
                    );
                    
                    // 3. Move pivot back
                    cellUV += 0.5;
                }
                
                // Assign the modified UVs back to your variable to sample the texture
                return cellUV;
            }
    
            SubdivResult subdivision( float3 p ) {
                SubdivResult result;

                // the initial size of a cell, it randomly halves
                result.size = _CellSize;

                for (int i = 0; i < _SubDivision; i++ ) {
                    // where is the center of the cell?
                    result.cell = ( floor( p / result.size ) + 0.5 ) * result.size;

                    // calculate a random hash for each cell
                    result.hash = pcg3df(result.cell);
                    result.i=i;

                    // should we subdiv more? (the condition uses the random hash)
                    if (i == 4 || result.hash.x < 0.5) {
                        break; // no
                    } else {
                        result.size *= 0.5; // yeah, halve the size and do this again
                    }
                }
                return result;
            }
            float gridOutline(float3 p, float3 cellSize, float lineWidth)
            {
                float3 localPos = abs(fmod(p + 0.5 * cellSize, cellSize) - 0.5 * cellSize);
                float3 halfSize = 0.5 * cellSize;
                float3 edgeDist = halfSize - localPos;

                // Thin line around each axis-aligned boundary
                float border = step(edgeDist.x, lineWidth) + step(edgeDist.y, lineWidth) + step(edgeDist.z, lineWidth);
                return saturate(border); // 0 or 1
            }
            fixed4 frag (v2f IN) : SV_Target
            {
                float beat = _Time.y * 90.0 / 60.0;//bpm
                float beatId = floor(beat);        // 第幾拍（整數）
                float beatPhase = frac(beat);      // 拍內 0..1
                float2 slideA = random1dto2d(beatId);
                float2 slideB = random1dto2d(beatId + 1.0);
                float ease = smoothstep(0.0, 1.0, beatPhase);
                //float ease = sin(beatPhase * PI * 0.5);
                float2 beatOffset = lerp(slideA, slideB, ease);

                float cycle = 1e-6 + 3;
                float timeMod = fmod(_Time.y, cycle);
                float seed = floor(_Time.y / cycle);
                float band = lerp(0.2, 1.2, random1dto1d(seed));
                float offset = lerp(0, 1, random1dto1d(seed+12));
                float pulseWidth = 1.05; // short duration (e.g. 5% of a cycle)
                float pulse = step(timeMod, pulseWidth * cycle) * saturate(timeMod / pulseWidth);

                // 中心化 & 控制幅度
                beatOffset = (beatOffset - 0.5) * 0.2;
                // beatOffset = (beatId % 10 < 1) ? (beatOffset - 0.5) * 0.2 : 0;

                float aspect = 1.777778 / 1;
                float2 uv = IN.uv;
                uv -= 0.5;
                uv.x *= aspect / lerp(1, aspect, _AspectScale); // comment it to apply a bit skew make it more 3d
                uv = rotate2d(uv, pulse * (offset-0.5)*2*_RotateScale);
                uv.x /= aspect / lerp(1, aspect, _AspectScale);
                uv += 0.5;
                uv.y /= aspect;
                uv = frac(uv * _GridSize);

                // coin-flip
                uv = lerp(uv.xy, uv.yx, saturate(fmod(floor(random1dto1d(seed+123)*2), 2) + 2 * _Flip));
                float postion = uv.y + offset;
                uv.x += timeMod * _SlideSpeed * step(band/2, fmod(postion, band)) * lerp(-1,1, fmod(floor(postion / band), 2)) * _GridTileScale;
                uv.x = frac(uv.x); // wrap-around
                
                // uv += beatOffset;
                // uv = RotateGrid(uv);
                // uv = octree(uv);
                SubdivResult subdiv = subdivision(float3(uv + float2(0.0,0) * _Time.y, 0.2 * _Time.y));
                // // col = subdiv.hash;
                // float2 scaledHash = subdiv.hash * float2(2.,1);
                // uv = subdiv.hash.xy;
                // uv += subdiv.hash.xy; // try affect the uv with grid
                // cell 的最小角
                float2 cellMin = subdiv.cell.xy - subdiv.size.xy * 0.5;
                // 0..1 的「cell 內 UV」
                float2 localUV = (uv - cellMin) / subdiv.size.xy;
                // 讓每個 cell 都是 0..1 重複 UV
                float2 tiledUV = frac(localUV);
                // 再用 hash 做 cell-level variation
                tiledUV += (subdiv.hash.xy - 0.5) * 0.15;
                uv = lerp(uv, tiledUV, _GridTileScale);
                float rate = random2dto1d(subdiv.hash*123.56);//+subdiv.size * _Time.y
                if (subdiv.size.x < _WhiteGridSizeThreshold)
                {
                    if (rate < _WhiteGridRate)
                        return rate % _WhiteGridRate < _WhiteGridRate*0.9 ? 1 : 0;
                    else if (rate < _WhiteGridRate+0.1)
                        uv = subdiv.hash.xy;
                }
                
                uv -= 0.5 * float2(1, 1 /aspect);
                // uv.y /= _ScreenParams.x / _ScreenParams.y;
                // uv.y /= 1.777778/1;
                uv *= _LetterScale;

                float3 pos = float3(uv, lerp(0,_Z2, pulse));
                float shouldDraw = step(subdiv.hash.z, _BorderRate);
                float border = gridOutline(pos, subdiv.size * _Size, 0.001) * shouldDraw; // 0.01 is line width
                
                sceneSwitchSpeed = lerp(1, subdiv.hash.x, _GridTileScale);
                float sceneTime = sceneSwitchSpeed * _Time.y;
                
                // 0: Circle // 1: Heart // 2: Star // 3: Lemniscate
                int scene = int(floor(mod(sceneTime, 4.0)));

                // 0: Black and white // 1: Pastel rainbow // 2: Red and purple // 3: Blue
                // Pick a random palette. Should use a better method with uniform distribution which
                // avoids picking the same value consecutively.
                float rand = mod(1.0 + 5.0 * hash11(floor(sceneTime+0.15)), 5.0);
                
                int palette = int(rand);

                if (_SceneIndex < 4)
                    scene = _SceneIndex;

                if (_PaletteIndex < 5)
                    palette = _PaletteIndex;
                // #if defined(_SCENE_ONE)
                //     scene = 1;
                // #elif defined(_SCENE_TWO)
                //     scene = 2;
                // #elif defined(_SCENE_THREE)
                //     scene = 3;
                // #elif defined(_SCENE_AUTO)
                // #endif
                #ifdef SCENE
                    scene = SCENE;
                #endif
                
                #ifdef PALETTE
                    palette = PALETTE;
                #endif
                
                float segments = _LetterSegment;
                float speed = _LetterSpeed;
                float radius = 0.5;
                float delta = (0.1 * (TWO_PI)) / segments;
                                              
                if(scene == 1){
                    segments *= 1.0;
                    speed *= 1.0;
                    delta = (0.15 * (TWO_PI)) / segments;
                }
                
                if(scene == 2){
                    radius = 0.5;
                    speed *= 4.0;
                    delta = (0.1 * (TWO_PI)) / segments;
                    // Rotate
                    float globalChangeIndex = floor(sceneTime);
                    float rnd = random1dto1d(globalChangeIndex) * 2 -1;
                    uv = rotate2d(uv, PI * rnd);
                }
                
                if(scene == 3){
                    segments *= 2;
                    speed *= .3;
                    delta = (0.2 * (TWO_PI)) / segments;
                }

                float t = speed * _Time.y;
                float slideIn = _SpacingSlideIn;
                // delta = (0.1 * (TWO_PI)) / segments; // small delta solve the scatter line
                // segments = 30.0;
                float angle = 0.0;
                float2 vUV = uv + float2(1.0,0.0);
                if (random(sceneSwitchSpeed*65.4321+_LetterSeed) > 0.5)
                {
                    angle += draw(vUV, 0, radius, segments/2, t+2., delta);
                    angle += draw(vUV, 0, radius, segments/2, t-1, delta);
                    vUV += float2(-getGap(0/5.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 1, radius, segments/3, t-2, delta);
                    angle += draw(vUV, 1, radius, segments/2, t, delta);
                    vUV += float2(-getGap(1/5.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 2, radius, segments, t, delta);
                    vUV += float2(-getGap(2/5.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 3, radius, segments/1.5, t+3, delta);
                    angle += draw(vUV, 3, radius, segments/2, t, delta);
                    vUV += float2(-getGap(3/5.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 1, radius, segments/2, t+1., delta);
                    angle += draw(vUV, 1, radius, segments/2, t, delta);
                    vUV += float2(-getGap(4/5.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 4, radius, segments/2, t-5, delta);
                    angle += draw(vUV, 4, radius, segments/2, t, delta);
                    
                    // angle += drawTest(vUV, radius, segments, t, delta);
                }
                else
                {
                    float palSeed = palette;//sceneTime;
                    palette = int(random1dto1d(palSeed) * 4); // make it wang_hash looks weird
                    angle += draw(vUV, 5, radius, segments/2, t+2., delta);
                    angle += draw(vUV, 5, radius, segments/2, t-1, delta);
                    vUV += float2(-getGap(0/6.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 6, radius, segments/3, t-2, delta);
                    angle += draw(vUV, 6, radius, segments/2, t, delta);
                    vUV += float2(-getGap(1/6.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 1, radius, segments/2, t, delta);
                    angle += draw(vUV, 1, radius, segments/3, t+1, delta);
                    vUV += float2(-getGap(2/6.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 7, radius, segments/1.5, t+3, delta);
                    angle += draw(vUV, 7, radius, segments/2, t, delta);
                    vUV += float2(-getGap(3/6.0, slideIn) - _Spacing, 0);
                    angle += draw(vUV, 2, radius, segments/2, t+1., delta);
                    angle += draw(vUV, 2, radius, segments/2, t, delta);
                    vUV += float2(-getGap(4/6.0, slideIn) - _Spacing, 0);
                    letterBound = float2(0,0.5);
                    angle += draw(vUV, 8, radius, segments/2, 2*t-5, delta);
                    letterBound = float2(0.5,1);
                    angle += draw(vUV, 8, radius, segments/2, 2*t, delta);
                    vUV += float2(-getGap(5/6.0, slideIn) - _Spacing, 0);
                    letterBound = float2(0,0.5);
                    angle += draw(vUV, 9, radius, segments/1.5, t+3, delta);
                    letterBound = float2(0.5,0.75);
                    angle += draw(vUV, 9, radius, segments/5, 2*t+0.7, delta*6);
                    letterBound = float2(0.75,1);
                    angle += draw(vUV, 9, radius, segments/5, 2*t, delta*6);
                }

                // float2 c0;
                // float2 c1;
                // for(float i = 0.0; i < segments; i += 1.){
                //     vUV = uv;
                //     c0 = radius * getT(t + 2. + (i) * delta);
                //     c1 = radius * getT(t + 2. + (i + 1.0) * delta);
                //     angle += signedAngle(c0-vUV, c1-vUV);
                // }
                // for(float i = 0.0; i < segments; i += 1.){
                //     vUV = uv;
                //     c0 = radius * getT(t + 2. + (i) * delta);
                //     c1 = radius * getT(t + 2. + (i + 1.0) * delta);
                //     angle += signedAngle(c0-vUV, c1-vUV);
                //     
                //     c0 = 0.866 * radius * getT(-t + (i) * delta);
                //     c1 = 0.866 * radius * getT(-t + (i + 1.0) * delta);
                //     //angle += signedAngle(c0-uv, c1-uv);
                // }
                // uv += float2(-spacing, 0);
                // for(float i = 0.0; i < segments; i += 1.){
                //     vUV = uv;
                //     // vUV = rotate2d(vUV, t);
                //     c0 = radius * getA(t + 1. + (i) * delta);
                //     c1 = radius * getA(t + 1. +(i + 1.0) * delta);
                //     angle += signedAngle(c0-vUV, c1-vUV);
                // }
                // uv += float2(-spacing, 0);
                // for(float i = 0.0; i < segments; i += 1.){
                //     c0 = radius * getI(t + (i) * delta);
                //     c1 = radius * getI(t + (i + 1.0) * delta);
                //     angle += signedAngle(c0-uv, c1-uv);
                // }
                // uv += float2(-spacing, 0);
                // for(float i = 0.0; i < segments; i += 1.){
                //     c0 = radius * getW(t + (i) * delta);
                //     c1 = radius * getW(t + (i + 1.0) * delta);
                //     angle += signedAngle(c0-uv, c1-uv);
                // }
                // uv += float2(-spacing, 0);
                // for(float i = 0.0; i < segments; i += 1.){
                //     c0 = radius * getA(t + (i) * delta);
                //     c1 = radius * getA(t + (i + 1.0) * delta);
                //     angle += signedAngle(c0-uv, c1-uv);
                // }
                // uv += float2(-spacing, 0);
                // for(float i = 0.0; i < segments; i += 1.){
                //     c0 = radius * getN(t + (i) * delta);
                //     c1 = radius * getN(t + (i + 1.0) * delta);
                //     angle += signedAngle(c0-uv, c1-uv);
                // }
                // uv += float2(-spacing, 0);

                
                // for(float i = 0.0; i < segments; i += 1.){
                //     c0 = 1 * getWarpedPosition(t + (i) * delta);
                //     c1 = 1 * getWarpedPosition(t + (i + 1.0) * delta);
                //     angle += signedAngle(c0-uv, c1-uv);
                // }
                // float3 uvw = float3(uv, 0);
                // uvw.xz = rotate2d(uvw.xz, _Time.y);
                // uv = rotate2d(uv, _Time.y);
                //
                // float a = sdA(uv.xy, 0.001);
                // a = pow(saturate(1-a),20);
                // // return a;
                // // sample the texture
                fixed3 col = getColour(angle / TWO_PI, palette, _Time.y) + _BorderColor * border.xxx;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
