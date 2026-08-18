// Pcx - URP-compatible disk point cloud shader for Unity 6.
// The legacy PCX geometry entry point is intentionally not used here; each
// disk is expanded to two triangles in the vertex stage instead.

Shader "Point Cloud/DiskUrp"
{
    Properties
    {
        _Tint("Tint", Color) = (0.5, 0.5, 0.5, 1)
        _PointSize("Point Size", Range(0,3)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "PCX URP Disk"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile _ _COMPUTE_BUFFER
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA

            #include "Assets/Shaders/Pcx/Disk.cginc"
            ENDHLSL
        }

        Pass
        {
            Name "PCX URP Disk ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile _ _COMPUTE_BUFFER
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #define PCX_SHADOW_CASTER 1

            #include "Assets/Shaders/Pcx/Disk.cginc"
            ENDHLSL
        }
    }

    CustomEditor "Pcx.DiskMaterialInspector"
}
