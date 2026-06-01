Shader "Unlit/RayRoom"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RayOrigin ("Ray Origin", Vector) = (0, 1.0, -3.5)
        _LookAt ("LookAt", Vector) = (0.0, -0.5, 1.0)
        _RoomSize ("Room Size", Vector) = (4.0, 4.0, 4.0)
        _Color1 ("Color 1", COlor) = (0, 0.1, 0.55)
        _Color2 ("Color 2", COlor) = (0.7, 0.5, 0.3)
        _SphereCenter ("Sphere Center", Vector) = (0.0, -1.0, 0.0)
        _SphereSize ("Sphere Size", Float) = 1.2
        _Ambient ("Ambient", Float) = 0.05
        _TileZoom ("TileZoom", Float) = 5
        _GridSize ("GridSize", Range(1, 10)) = 1
        _LetterSpeed ("Letter Speed", Float) = 0.5
        _LetterSeed ("Letter Seed", Int) = 0
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

            #include "UnityCG.cginc"

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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float3 _RayOrigin;
            float3 _LookAt;
            float3 _RoomSize;
            float4 _Color1;
            float4 _Color2;
            float3 _SphereCenter;
            float _SphereSize;
            float _Ambient;
            float _TileZoom;
            
            #ifndef PI
            #define PI 3.1415926535897932384626433832795
            #endif

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // Distance function for a sphere
            float sdSphere(float3 p, float r) {
                return length(p) - r;
            }

            // Distance function for an inverted box (the room)
            float sdRoom(float3 p, float3 size) {
                float3 d = abs(p) - size;
                // Invert the distance because we are INSIDE the box
                return -max(d.x, max(d.y, d.z));
            }

            // The Scene Map: combines all objects
            // Returns float2(distance, object_id)
            float2 map(float3 p) {
                // 1. The Room walls (Size 4x4x4)
                float3 d = abs(p) - _RoomSize;
                float roomDist = -max(d.x, max(d.y, d.z));
                float2 res = float2(roomDist, 1.0); // ID 1.0 = Walls/Ceiling
                
                // 2. Separate the Floor (If the hit point is near the bottom wall)
                // The bottom wall is at y = -4.0. We check if we are close to it.
                if (p.y < -3.99) {
                    res.y = 2.0; // ID 2.0 = Floor
                }
                
                // 3. The floating sphere
                float sphereDist = length(p - _SphereCenter) - _SphereSize;
                if (sphereDist < res.x) {
                    res = float2(sphereDist, 3.0); // ID 3.0 = Sphere
                }
                
                return res;
            }

            // Calculate normals using central differences
            float3 getNormal(float3 p) {
                float2 e = float2(0.001, 0.0);
                return normalize(float3(
                    map(p + e.xyy).x - map(p - e.xyy).x,
                    map(p + e.yxy).x - map(p - e.yxy).x,
                    map(p + e.yyx).x - map(p - e.yyx).x
                ));
            }

            // Returns a float2 where .x is final distance, .y is the object ID it hit
            float2 raymarch(float3 ro, float3 rd) {
                float dO = 0.0;
                float id = -1.0;
                for(int i = 0; i < 100; i++) {
                    float3 p = ro + rd * dO;
                    float2 res = map(p);
                    dO += res.x;
                    id = res.y;
                    if(dO > 40.0 || abs(res.x) < 0.001) break;
                }
                return float2(dO, id);
            }

            float getShadow(float3 ro, float3 rd, float mint, float maxt) {
                float t = mint;
                for(int i = 0; i < 50; i++) {
                    float h = map(ro + rd * t).x; // Just look at the distance component (.x)
                    if(h < 0.001) return 0.0; 
                    t += h;
                    if(t > maxt) break;
                }
                return 1.0;
            }

            float2 rotate2D( in float2 uv, in float alpha )
            {
                float c = cos(alpha);
                float s = sin(alpha);
                uv =  mul(float2x2(c, -s, s, c), uv - 0.5) + 0.5;
                return uv;
            }

            float2 tile(in float2 uv, float zoom)
            {
                return frac(uv * zoom);
            }

            float box( in float2 uv, in float2 size, in float smoothEdges )
            {
                size = 0.5 - size * 0.5;
                float2 aa = smoothEdges*0.5;
                float2 st = smoothstep( size, size+aa, uv)
                      * smoothstep( size, size+aa, 1.0 - uv);    
                return st.x * st.y;
            }

            float circle( in float2 uv, in float radius, in float smoothEdges )
            {
                // 1. Calculate the distance of the current pixel from the center (0.5, 0.5)
                float d = length(uv - 0.5); // Note: Use float2 if writing in HLSL/Cg
                
                // 2. Define the half-width of our smoothing transition range
                float aa = smoothEdges * 0.5;
                
                // 3. Smoothly transition from 1.0 (inside radius) to 0.0 (outside radius)
                // We invert the smoothstep order so it returns 1.0 on the inside
                return smoothstep(radius + aa, radius - aa, d);
            }

            float sdCircle( float2 p, float r )
            {
                return length(p) - r;
            }

            float checkerboard(float2 uv) {
                float2 f = floor(frac(uv) * 2.0);
                return fmod(f.x + f.y, 2.0);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Normalized pixel coordinates (from -1 to 1)
                // float2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
                float2 uv = (2.0 * i.vertex.xy - _ScreenParams.xy) / _ScreenParams.y;

                // Camera setup
                // Animate camera gently using iTime
                float3 ro = _RayOrigin + float3(2.5 * sin(_Time.y * 0.2), 0, 0);//float3(2.5 * sin(_Time.y * 0.2), 1.0, -3.5); 
                float3 lookAt = _LookAt;//float3(0.0, -0.5, 1.0);
                
                // Camera vectors
                float3 f = normalize(lookAt - ro);
                float3 r = normalize(cross(float3(0.0, 1.0, 0.0), f));
                float3 u = cross(f, r);
                
                // Ray direction
                float3 rd = normalize(f + uv.x * r + uv.y * u);

                // Render logic
                float3 col = 0.0;
                float2 rm = raymarch(ro, rd); // Returns float2(distance, id)
                float d = rm.x;
                float objID = rm.y;
                
                if(d < 40.0) {
                    float3 p = ro + rd * d;      // Hit point
                    float3 n = getNormal(p);     // Surface normal
                    
                    // Animated Light Source position
                    float3 lightPos = float3(2.0 * sin(_Time.y), 3.0, 1.0 + 2.0 * cos(_Time.y));
                    float3 l = normalize(lightPos - p);

                    // Diffuse lighting (Lambertian)
                    float dif = clamp(dot(n, l), 0.0, 1.0);
                    
                    // Calculate Shadow
                    // Offset the ray origin slightly along normal to prevent self-shadowing acne
                    float shadow = getShadow(p + n * 0.05, l, 0.01, length(lightPos - p));
                    
                    // --- MATERIAL / COLOR SELECTION BASE ON ID ---
                    float3 diffuseColor = 1.0; // Default fallback (white)
                    
                    if (objID == 1.0) { // Walls and Ceiling
                        float2 wallUV = uv;
                        
                        // Check if the wall faces left/right (X-axis) or front/back (Z-axis)
                        if (abs(n.x) > 0.5) {
                            // Side walls: Use Z and Y for the texture coordinates
                            wallUV = p.zy;
                        } else if (abs(n.z) > 0.5) {
                            // Back wall: Use X and Y for the texture coordinates
                            wallUV = p.xy;
                        } else {
                            // Ceiling (facing down on the Y-axis): Use X and Z
                            wallUV = p.xz;
                        }
                        
                        // Scale the UVs to make the pattern repeating
                        wallUV *= 0.5; 

                        // // Sample your pattern using the world space coordinates
                        // float pattern = checkerboard(wallUV);
                        //
                        // // Mix two colors together based on the pattern
                        // float3 colorA = float3(0.7, 0.5, 0.3); // Beige
                        // float3 colorB = float3(0.4, 0.2, 0.1); // Dark Brown
                        // diffuseColor = lerp(colorA, colorB, pattern); //float3(0.7, 0.5, 0.3); // Beige Walls
                        
                        float shiftAngle = PI * 0.25;
                        // float angle = mod( 1.0 * _Time.y, PI) + shiftAngle;
                        float angle = _Time.y - PI * floor(_Time.y / PI) + shiftAngle;
                        float doShift = step(angle, PI-shiftAngle);
                        float2 shiftOffset = float2(-0.5, 0.5) / _TileZoom;
                        
                        wallUV += doShift * shiftOffset;
                        wallUV = tile(wallUV, _TileZoom);
                        wallUV = rotate2D(wallUV, angle);
                        
                        float ic = abs(box(wallUV, float2(0.71, 0.71), 0.012) - doShift) - sdCircle(wallUV - 0.5, 0.2);
                        // float ic = abs(sdCircle(wallUV, 0.71) - doShift);
                        float3 pattern = ic > 0 ? _Color1 : _Color2;
                        diffuseColor = pattern;
                    }
                    else if (objID == 2.0) {
                        diffuseColor = float3(0.2, 0.6, 0.4); // Green Floor
                    } 
                    else if (objID == 3.0) {
                        diffuseColor = float3(0.8, 0.2, 0.2); // Red Sphere
                    }
                    // ----------------------------------------------
                    
                    col = diffuseColor * (dif * shadow) + _Ambient;
                    
                    // Gamma correction
                    col = pow(col, 0.4545);
                }

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
