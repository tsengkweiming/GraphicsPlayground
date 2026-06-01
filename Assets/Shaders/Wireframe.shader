Shader "Custom/ViewportWireframe"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        _WireColor ("Wire Color", Color) = (0.1, 0.1, 0.1, 1)
        _WireThickness ("Wire Thickness", Range(0, 10)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2g
            {
                float4 projectionSpaceVertex : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
            };

            struct g2f
            {
                float4 projectionSpaceVertex : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float3 barycentric : TEXCOORD3;
            };

            fixed4 _BaseColor;
            fixed4 _WireColor;
            float _WireThickness;

            v2g vert (appdata v)
            {
                v2g o;
                o.projectionSpaceVertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                return o;
            }

            // Geometry shader generates barycentric coordinates for each triangle
            [maxvertexcount(3)]
            void geom(triangle v2g i[3], inout TriangleStream<g2f> tristream)
            {
                g2f o;
                
                // Vertex 1
                o.projectionSpaceVertex = i[0].projectionSpaceVertex;
                o.worldNormal = i[0].worldNormal;
                o.viewDir = i[0].viewDir;
                o.barycentric = float3(1, 0, 0);
                tristream.Append(o);

                // Vertex 2
                o.projectionSpaceVertex = i[1].projectionSpaceVertex;
                o.worldNormal = i[1].worldNormal;
                o.viewDir = i[1].viewDir;
                o.barycentric = float3(0, 1, 0);
                tristream.Append(o);

                // Vertex 3
                o.projectionSpaceVertex = i[2].projectionSpaceVertex;
                o.worldNormal = i[2].worldNormal;
                o.viewDir = i[2].viewDir;
                o.barycentric = float3(0, 0, 1);
                tristream.Append(o);
            }

            fixed4 frag (g2f i) : SV_Target
            {
                // Calculate the screen-space derivatives to keep wire width constant regardless of distance
                float3 d = fwidth(i.barycentric);
                float3 a3 = smoothstep(float3(0,0,0), d * _WireThickness, i.barycentric);
                float minBary = min(min(a3.x, a3.y), a3.z);
                
                // Simple lambertian shading to mimic the 3D viewport look
                float3 normal = normalize(i.worldNormal);
                float3 viewDir = normalize(i.viewDir);
                float ndotl = max(0.3, dot(normal, float3(0.5, 1.0, 0.5))); // Fake directional light from top-left

                fixed4 surfaceColor = _BaseColor * ndotl;
                
                // Blend between the surface color and the wireframe color
                return lerp(_WireColor, surfaceColor, minBary);
            }

            // Helper function for blending
            float4 mix(float4 a, float4 b, float t)
            {
                return a + (b - a) * t;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}