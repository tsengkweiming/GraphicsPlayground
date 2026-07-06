// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/CustomPostProcess/MaskBloom" {
	Properties{
		_MainTex("Base (RGB)", 2D) = "white" {}
	}

	CGINCLUDE

	#include "UnityCG.cginc"

	sampler2D _MainTex;
	sampler2D _BlurTex;
	half _Intensity;
	
	uniform half4 _MainTex_TexelSize;
	uniform half4 _Offset;
	float _Gain;
	float2 _LerpInStartEnd;
	float2 _LerpOutStartEnd;
	float _MaskIntensity;
	float _Contrast;
	sampler2D _AlphaMask;
	
	struct v2f_tap
	{
		float4 pos : SV_POSITION;
		half2 uv20 : TEXCOORD0;
		half2 uv21 : TEXCOORD1;
		half2 uv22 : TEXCOORD2;
		half2 uv23 : TEXCOORD3;
	};

	v2f_tap vert4Tap(appdata_img v)
	{
		v2f_tap o;

		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv20 = v.texcoord + _MainTex_TexelSize.xy;
		o.uv21 = v.texcoord + _MainTex_TexelSize.xy * half2(-0.5h, -0.5h);
		o.uv22 = v.texcoord + _MainTex_TexelSize.xy * half2(0.5h, -0.5h);
		o.uv23 = v.texcoord + _MainTex_TexelSize.xy * half2(-0.5h, 0.5h);

		return o;
	}

	fixed4 fragDownsample(v2f_tap i) : COLOR
	{
		fixed4 color = tex2D(_MainTex, i.uv20);
		color += tex2D(_MainTex, i.uv21);
		color += tex2D(_MainTex, i.uv22);
		color += tex2D(_MainTex, i.uv23);
		return color / 4;
	}

	// weight curves

	static const half curve[7] = { 0.0205, 0.0855, 0.232, 0.324, 0.232, 0.0855, 0.0205 };  // gauss'ish blur weights

	static const half4 curve4[7] = { half4(0.0205,0.0205,0.0205,0.0205), half4(0.0855,0.0855,0.0855,0.0855), half4(0.232,0.232,0.232,0.232),
		half4(0.324,0.324,0.324,0.324), half4(0.232,0.232,0.232,0.232), half4(0.0855,0.0855,0.0855,0.0855), half4(0.0205,0.0205,0.0205,0.0205) };

	struct v2f {
		float4 pos : SV_POSITION;
		float2 uv[2] : TEXCOORD0;
	};
	
	struct v2f_withBlurCoords8
	{
		float4 pos : SV_POSITION;
		half4 uv : TEXCOORD0;
		half2 offs : TEXCOORD1;
	};

	struct v2f_withBlurCoordsSGX
	{
		float4 pos : SV_POSITION;
		half2 uv : TEXCOORD0;
		half4 offs[3] : TEXCOORD1;
	};

	v2f_withBlurCoords8 vertBlurHorizontal(appdata_img v)
	{
		v2f_withBlurCoords8 o;
		o.pos = UnityObjectToClipPos(v.vertex);

		o.uv = half4(v.texcoord.xy, 1, 1);
		o.offs = _MainTex_TexelSize.xy * half2(1.0, 0.0) * _Offset.x;

		return o;
	}

	v2f_withBlurCoords8 vertBlurVertical(appdata_img v)
	{
		v2f_withBlurCoords8 o;
		o.pos = UnityObjectToClipPos(v.vertex);

		o.uv = half4(v.texcoord.xy, 1, 1);
		o.offs = _MainTex_TexelSize.xy * half2(0.0, 1.0) * _Offset.x;

		return o;
	}

	half4 fragBlur8(v2f_withBlurCoords8 i) : COLOR
	{
		half2 uv = i.uv.xy;
		half2 netFilterWidth = i.offs;
		half2 coords = uv - netFilterWidth * 3.0;

		half4 color = 0;
		for (int l = 0; l < 7; l++)
		{
			half4 tap = tex2D(_MainTex, coords);
			color += tap * curve4[l];
			coords += netFilterWidth;
		}
		return color;
	}


	v2f_withBlurCoordsSGX vertBlurHorizontalSGX(appdata_img v)
	{
		v2f_withBlurCoordsSGX o;
		o.pos = UnityObjectToClipPos(v.vertex);

		o.uv = v.texcoord.xy;
		half2 netFilterWidth = _MainTex_TexelSize.xy * half2(1.0, 0.0) * _Offset.x;
		half4 coords = -netFilterWidth.xyxy * 3.0;

		o.offs[0] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);
		coords += netFilterWidth.xyxy;
		o.offs[1] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);
		coords += netFilterWidth.xyxy;
		o.offs[2] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);

		return o;
	}

	v2f_withBlurCoordsSGX vertBlurVerticalSGX(appdata_img v)
	{
		v2f_withBlurCoordsSGX o;
		o.pos = UnityObjectToClipPos(v.vertex);

		o.uv = half4(v.texcoord.xy, 1, 1);
		half2 netFilterWidth = _MainTex_TexelSize.xy * half2(0.0, 1.0) * _Offset.x;
		half4 coords = -netFilterWidth.xyxy * 3.0;

		o.offs[0] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);
		coords += netFilterWidth.xyxy;
		o.offs[1] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);
		coords += netFilterWidth.xyxy;
		o.offs[2] = v.texcoord.xyxy + coords * half4(1.0h, 1.0h, -1.0h, -1.0h);

		return o;
	}

	half4 fragBlurSGX(v2f_withBlurCoordsSGX i) : COLOR
	{
		half2 uv = i.uv.xy;

		half4 color = tex2D(_MainTex, i.uv) * curve4[3];

		for (int l = 0; l < 3; l++)
		{
			half4 tapA = tex2D(_MainTex, i.offs[l].xy);
			half4 tapB = tex2D(_MainTex, i.offs[l].zw);
			color += (tapA + tapB) * curve4[l];
		}

		#if BLUR_GAIN
			color *= _Gain;
		#endif
	
		return color;
	}
	
	float Contrast(float value, float contrast)
	{
		return (value - 0.5) * contrast + 0.5;
	}
	
	float SCurveContrast(float n, float contrast)
	{
		return n = n < 0.5 ? pow(n * 2, contrast) * 0.5 : (1.0 - pow(2.0 * (1.0 - n), contrast) * 0.5);
	}
	
	fixed4 fragMask(v2f_img i) : COLOR
	{
		half4 c = tex2D(_MainTex, i.uv);
		float alphaMask = tex2D(_AlphaMask, i.uv).r;
		alphaMask = saturate(alphaMask * _MaskIntensity);
		half alpha = 1;
		if (alphaMask < _LerpInStartEnd.y)
			alpha = saturate((alphaMask - _LerpInStartEnd.x) / (_LerpInStartEnd.y - _LerpInStartEnd.x));
		if (alphaMask > _LerpOutStartEnd.x)
			alpha = 1 - saturate((alphaMask - _LerpOutStartEnd.x) / (_LerpOutStartEnd.y - _LerpOutStartEnd.x));
		alpha = SCurveContrast(alpha, max(_Contrast, 0));
	
		c.rgb *= alpha;
		c.a = alpha;
		return saturate(c);
	}

	half4 mask(half4 src, half4 color) {
		return lerp(src, color, 1.0 - src.a);
	}

	half4 fragScreen(v2f i) : SV_Target{
		half4 screencolor = tex2D(_MainTex, i.uv[0]);
		half4 addedbloom = tex2D(_BlurTex, i.uv[1].xy);
		half4 result = 1 - (1 - addedbloom * _Intensity) * (1 - screencolor);
		return mask(screencolor, result);
	}

	half4 fragAdd(v2f i) : SV_Target{
		half4 screencolor = tex2D(_MainTex, i.uv[0].xy);
		half4 addedbloom = tex2D(_BlurTex, i.uv[1].xy);
		half4 result = _Intensity * addedbloom + screencolor;
		return mask(screencolor, result);
	}
	ENDCG

	SubShader {
		ZTest Off Cull Off ZWrite Off Blend Off
		Fog{ Mode off }

		// 0
		Pass{

			CGPROGRAM

			#pragma vertex vert4Tap
			#pragma fragment fragDownsample
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}

		// 1  Mask
		Pass{
			ZTest Always
			Cull Off

			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment fragMask
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}

		// 2
		Pass{
			ZTest Always
			Cull Off

			CGPROGRAM

			#pragma vertex vertBlurVertical
			#pragma fragment fragBlur8
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}

		// 3
		Pass{
			ZTest Always
			Cull Off

			CGPROGRAM

			#pragma vertex vertBlurHorizontal
			#pragma fragment fragBlur8
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}

		// 4 : Bloom (Screen)
		Pass {
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment fragScreen
			ENDCG
		}

		// 5 : Bloom (Add)
		Pass {
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment fragAdd
			ENDCG
		}

		// alternate blur
		// 6
		Pass{
			ZTest Always
			Cull Off

			CGPROGRAM
			#pragma multi_compile __ BLUR_GAIN
			#pragma vertex vertBlurVerticalSGX
			#pragma fragment fragBlurSGX
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}

		// 7
		Pass{
			ZTest Always
			Cull Off

			CGPROGRAM
			#pragma vertex vertBlurHorizontalSGX
			#pragma fragment fragBlurSGX
			#pragma fragmentoption ARB_precision_hint_fastest

			ENDCG
		}
	}
	FallBack Off
}
