Shader "Unlit/RayCubicGridPlane"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RayOrigin ("Ray Origin", Vector) = (0,7.2,-14.)
        _LookAt ("LookAt", Vector) = (-1,-3,0.5)
        _RoomSize ("Room Size", Vector) = (4.0, 4.0, 4.0)
        _Color1 ("Color 1", COlor) = (0, 0.1, 0.55)
        _Color2 ("Color 2", COlor) = (0.7, 0.5, 0.3)
        _SphereCenter ("Sphere Center", Vector) = (0.0, -1.0, 0.0)
        _SphereSize ("Sphere Size", Float) = 1.2
        _Ambient ("Ambient", Float) = 0.05
        _TileZoom ("TileZoom", Float) = 5
        _UVLerp ("UV Lerp", Range(0,1)) = 1
        [Toggle(Light Switch)]_LightSwitch ("Light Switch", Float) = 1
        [Toggle(DivTest Switch)]_DivSwitch ("Div Switch", Float) = 1
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
            float3 _Mouse;
            float _LightSwitch;
            float _DivSwitch;
            float _UVLerp;
            
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

            #define MDIST 150.0
            #define STEPS 164.0
            #define pi 3.1415926535
            #define pmod(p,x) (mod(p,x)+0.5*(x))
            #define rot(a) float2x2(cos(a),sin(a),-sin(a),cos(a))
            #define AO(a,n,p) smoothstep(-a,a,map(p+n*a, rd, false).x)

            //this is a useless trick but it's funny
            #define vmm(v,minOrMax) minOrMax(v.x,minOrMax(v.y,v.z))

            //iq box sdf
            float ebox( float3 p, float3 b ){
              float3 q = abs(p) - b;
              return length(max(q,0.0)) + min(vmm(q,max),0.0);
            }
            //iq palette
            float3 pal( in float t, in float3 a, in float3 b, in float3 c, in float3 d ){
                return a + b*cos(2.*pi*(c*t+d));
            }
            float h11 (float a) {
                return frac(sin((a)*12.9898)*43758.5453123);
            }
            //https://www.shadertoy.com/view/fdlSDl
            float2 tanha(float2 x) {
              float2 x2 = x*x;
              return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
            }
            float tanha(float x) {
              float x2 = x*x;
              return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
            }

            struct sdResult
            {
                float2 center;
                float2 dim;
                float id;
                float vol;
            };

            sdResult subdiv(float2 p,float seed){
                float2 dMin = -10.;
                float2 dMax = 10.;
                float t = _Time.y*0.2;
                float t2 = _Time.y*0.33333;
                float2 dim = dMax - dMin;
                float id = 0.;
                float ITERS = 6.;
                
                float MIN_SIZE = 0.1;
                float MIN_ITERS = 1.;
                
                //big thanks to @0b5vr for letting me use his cleaner subdiv implementation
                //https://www.shadertoy.com/view/NsKGDy
                float2 diff2 = 1;
                for(float i = 0.;i<ITERS;i++){
                    float2 divHash=tanha(float2(sin(t2*pi/3.+id+i*t2*0.05),cos(t2*pi/3.+h11(id)*100.+i*t2*0.05))*3.)*0.35+0.5;
                    //divHash=float2(sin(t*pi/3.+id),cos(t*pi/3.+h11(id)*100.))*0.5+0.5;
                    //if(iMouse.z>0.5){divHash = mix(divHash,M,0.9);}
                    divHash = _DivSwitch > 0 ? lerp(0.5,divHash,tanha(sin(t*0.8)*5.)*0.2+0.4) : 0.5;//
                    float2 divide = divHash * dim + dMin;
                    divide = clamp(divide, dMin + MIN_SIZE+0.01, dMax - MIN_SIZE-0.01);
                    float2 minAxis = min(abs(dMin - divide), abs(dMax - divide));
                    float minSize = min( minAxis.x, minAxis.y);
                    bool smallEnough = minSize < MIN_SIZE;
                    if (smallEnough && i + 1. > MIN_ITERS) { break; }
                    dMax = lerp( dMax, divide, step( p, divide ));
                    dMin = lerp( divide, dMin, step( p, divide ));
                    diff2 =step( p, divide)-
                    float2(h11(diff2.x+seed)*10.,h11(diff2.y+seed)*10.);
                    id = length(diff2)*100.0;
                    dim = dMax - dMin;
                }
                float2 center = (dMin + dMax)/2.0;
                sdResult result;
                result.center = center;
                result.id = id;
                result.dim = dim;
                result.vol = dim.x*dim.y;
                return result;
            }
            float3 rdg = 0;
            float dibox(float3 p,float3 b,float3 rd){
                float3 dir = sign(rd)*b;   
                float3 rc = (dir-p)/rd;
                return min(rc.x,rc.z)+0.01; 
            }
            // bool traverse = true;
            float3 map(float3 p, float3 rdg, bool traverse){
                float seed = sign(p.y)-0.3;
                seed = 1.;
                //p.y = abs(p.y)-4.;

                float2 a = float2(99999,1);
                float2 b = 2;
                
                a.x = p.y-2.0;
                float id = 0.;
                if(a.x<0.1||!traverse){
                    float t = _Time.y;
                    sdResult sdr = subdiv(p.xz,seed);
                    float3 centerOff = float3(sdr.center.x,0,sdr.center.y);
                    float2 dim = sdr.dim;

                    float rnd = 0.05;
                    float size = min(dim.y,dim.x)*1.;
                    // size = 1.;
                    size+=(sin((centerOff.x+centerOff.z)*0.6+t*4.5)*0.5+0.5)*2.;
                    size = min(size,4.0);
                    a.x = ebox(p-centerOff-float3(0,0,0),float3(dim.x,size,dim.y)*0.5-rnd)-rnd;
                    if(traverse){
                        b.x = dibox(p-centerOff,float3(dim.x,1,dim.y)*0.5,rdg);
                        a = (a.x<b.x)?a:b;
                    }
                    id = sdr.id;
                }
                return float3(a,id);
            }
            float3 norm(float3 p, float3 rdg, bool traverse){
                float2 e = float2(0.01,0.);
                return normalize(map(p, rdg, traverse).x - float3(
                    map(p-e.xyy, rdg, traverse).x,
                    map(p-e.yxy, rdg, traverse).x,
                    map(p-e.yyx, rdg, traverse).x));
            }
            float checkerboard(float2 uv) {
                float2 f = floor(frac(uv) * 2.0);
                return fmod(f.x + f.y, 2.0);
            }

            float2 rotate2D(float2 uv, float alpha)
            {
                float c = cos(alpha);
                float s = sin(alpha);
                return mul(float2x2(c, -s, s, c), uv - 0.5) + 0.5;
            }

            float2 tile(float2 uv, float zoom)
            {
                return frac(uv * zoom);
            }

            float box2D(float2 uv, float2 size, float smoothEdges)
            {
                size = 0.5 - size * 0.5;
                float2 aa = smoothEdges * 0.5;

                float2 st = smoothstep(size, size + aa, uv)
                          * smoothstep(size, size + aa, 1.0 - uv);

                return st.x * st.y;
            }

            float sdCircle(float2 p, float r)
            {
                return length(p) - r;
            }

            float rectTile(float2 uv)
            {
                float shiftAngle = PI * 0.25;
                float angle = _Time.y - PI * floor(_Time.y / PI) + shiftAngle;
                float doShift = step(angle, PI - shiftAngle);

                float2 shiftOffset = float2(-0.5, 0.5) / _TileZoom;

                uv += doShift * shiftOffset;
                uv = tile(uv, _TileZoom);
                uv = rotate2D(uv, angle);

                float rect = box2D(uv, float2(0.71, 0.71), 0.012);
                float circ = sdCircle(uv - 0.5, 0.2);

                return step(0.0, abs(rect - doShift) - 0.5);
            }
                        
            fixed4 frag (v2f IN) : SV_Target
            {
                // Normalized pixel coordinates (from -1 to 1)
                float2 uv = (2.0 * IN.vertex.xy - _ScreenParams.xy) / _ScreenParams.y / 2.0;

                float3 col = 0;
    
                float3 ro = _RayOrigin;//float3(0,6.,0.5);

                ro.xz=mul(rot(0.35), ro.xz);
                float3 lookAt = _LookAt;//float3(0,-3,0.5);
                if(_Mouse.z>0.){
                   ro*=2.;
                   lookAt = 0;
                   ro.yz=mul(rot(2.0*(_Mouse.y-0.5)),ro.yz);
                   ro.zx=mul(rot(-9.0*(_Mouse.x-0.5)),ro.zx);
                }
                float3 f = normalize(lookAt - ro);
                float3 r = normalize(cross(float3(0,1,0),f));
                float3 rd = normalize(f*(1.8)+r*uv.x+uv.y*cross(f,r));
                rdg = rd;
                float3 p = ro;
                float dO =0.;
                float3 d;
                bool hit = false;

                for (int step = 0; step < STEPS; step++)
                {
                    p = ro + rd * dO;
                    d = map(p, rd, true);
                    dO += d.x;

                    if (d.x < 0.005)
                    {
                        hit = true;
                        break;
                    }

                    if (dO > MDIST) break;
                }
                
                if(hit&&d.y!=2.0){
                    // traverse = false;
                    float3 n = norm(p, rd, false);
                    float3 r = reflect(rd,n);
                    float3 e = 0.5;
                    float3 albedo = pal(frac(d.z)*0.35-0.8,e*1.2,e,e*2.0,float3(0,0.33,0.66));
                    
                    float2 cubeUV;
                    float3 an = abs(n);
                    if (an.y > an.x && an.y > an.z)
                    {
                        cubeUV = p.xz;
                    }
                    else if (an.x > an.z)
                    {
                        cubeUV = p.zy;
                    }
                    else
                    {
                        cubeUV = p.xy;
                    }

                    cubeUV = frac(cubeUV * 0.5);
                    sdResult sdr = subdiv(p.xz, 1.0);
                    float2 localUV = (p.xz - (sdr.center - sdr.dim * 0.5)) / sdr.dim / 1;
                    localUV = saturate(localUV);
                    float pat = rectTile(lerp(cubeUV, localUV, _UVLerp));

                    float3 patternCol = lerp(_Color1.rgb, _Color2.rgb, pat);
                    albedo = patternCol;
                    col = albedo;
                    float3 ld = normalize(float3(0,45,0)-p);

                    //sss from nusan
                    float sss=0.1;
                    float sssteps = 10.;
                    for (float s = 1; s < sssteps; s++)
                    {
                        float dist = s * 0.2;
                        sss += smoothstep(0.0, 1.0, map(p + ld * dist, rd, false).x / dist) / 15.0;
                    }
                    sss = clamp(sss,0.0,1.0);
                    
                    //blackle ao 
                    float ao = AO(0.1,n,p)*AO(.2,n,p)*AO(.3,n,p);
                    
                    // float diff = max(0.,dot(n,ld))*0.7+0.3;
                    // float amb = dot(n,ld)*0.45+0.55;
                    // float spec = pow(max(0.,dot(r,ld)),13.0);
                    // spec = smoothstep(0.,1.,spec);
                    // col = float3(0.204,0.267,0.373)*
                    // lerp(float3(0.169,0.000,0.169),float3(0.984,0.996,0.804),lerp(amb,diff,0.75))
                    // +spec*0.3;
                    // col+=sss*albedo;
                    // col*=lerp(ao,1.,0.65);
                    // col = pow(col,0.85);

                    float3 baseCol = albedo;
                    float diff = max(0.0, dot(n, ld));
                    float amb = 0.35;
                    float spec = pow(max(0.0, dot(reflect(rd, n), ld)), 32.0);

                    if (_LightSwitch > 0)
                    {
                        col = baseCol * (amb + diff * 0.8);
                        col += spec * 0.35;
                        col *= lerp(ao, 1.0, 0.6);
                        col += sss * baseCol * 0.4;
                    }
                    else
                    {
                        col = baseCol;
                    }
                }
                else{
                    col = lerp(float3(0.373,0.835,0.988),float3(0.424,0.059,0.925),length(uv));
                }
                
                col *=1.0-0.5*pow(length(uv*float2(0.8,1.)),2.7);
                float3 col2 = smoothstep(float3(0.0, 0.0, 0.0), float3(1.1, 1.1, 1.3), col);
                col = lerp(col,col2,0.5)*1.05;

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
