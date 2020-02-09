﻿// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Scatterer/CausticsOcclusion"
{
    Properties
    {
    	_CausticsTexture ("_CausticsTexture", 2D) = "" {}
    	layer1Scale ("Layer 1 scale", Vector) = (1.0101,1.0101,0)
    	layer1Speed ("Layer 1 speed", Vector) = (0.05123,0.05123,0)
    	layer2Scale ("Layer 2 scale", Vector) = (1.235487,1.235487,0)
    	layer2Speed ("Layer 2 speed", Vector) = (0.074872,0.074872,0)
    	causticsMultiply ("causticsMultiply", Float) = 1
    	causticsMinBrightness ("causticsMinBrightness", Float) = 0.1
    }

	SubShader
	{
		Pass
		{
			Cull Back ZWrite Off ZTest Off
			Blend DstColor Zero  // Multiplicative
			//Blend SrcAlpha OneMinusSrcAlpha //alpha blending
			//Blend One One  // Additive

			CGPROGRAM
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0

			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 CameraToWorld;

			sampler2D _CausticsTexture;
			float4x4 WorldToLight;

			uniform float2 layer1Scale;
			uniform float2 layer1Speed;

			uniform float2 layer2Scale;
			uniform float2 layer2Speed;

			uniform float causticsMultiply;
			uniform float causticsMinBrightness;

			struct v2f 
			{
    			float4  pos : SV_POSITION;
    			float2  uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
    			v2f OUT;
    			OUT.pos = UnityObjectToClipPos(v.vertex);
				OUT.uv = ComputeScreenPos(OUT.pos);

    			return OUT;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float zdepth = tex2Dlod(_CameraDepthTexture, float4(i.uv,0,0));

#ifdef SHADER_API_D3D11  //#if defined(UNITY_REVERSED_Z)
        			zdepth = 1 - zdepth;
#endif

    			float4 clipPos = float4(i.uv, zdepth, 1.0);
    			clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
    			float4 camPos = mul(unity_CameraInvProjection, clipPos);
				float4 worldPos = mul(CameraToWorld,camPos);
				worldPos/=worldPos.w;

//				camPos.xyz /= camPos.w;
//				float fragDistance = length(camPos.xyz) / 100.0;
//				return float4(fragDistance,fragDistance,fragDistance,1.0);


//				float worldDist = length(worldPos.xyz) / 1000.0;
//				worldDist = 1 - worldDist;
				//return float4(worldDist,worldDist,worldDist,1.0);

				// blur caustics the farther we are from texture
				//float blurFactor = lerp(0.0,5.0,-worldPos.y/30.0);
				float blurFactor = 0.0;

				float2 uvCookie = mul(WorldToLight, float4(worldPos.xyz, 1)).xy;

    			float2 uvSample1 = layer1Scale * uvCookie + layer1Speed * float2(_Time.y,_Time.y);
				float2 uvSample2 = layer2Scale * uvCookie + layer2Speed * float2(_Time.y,_Time.y);

				float causticsSample1 = tex2Dbias(_CausticsTexture,float4(uvSample1,0.0,blurFactor)).r;
				float causticsSample2 = tex2Dbias(_CausticsTexture,float4(uvSample2,0.0,blurFactor)).r;

				//fadeOutCaustics when the blur gets too strong, doesn't work well, figure it out later
				//float fadeOut = clamp(10.0-blurFactor,0.0,1.0);

				float caustics = causticsMultiply*min(causticsSample1,causticsSample2)+causticsMinBrightness;
				return float4(caustics,caustics,caustics,1.0);
			}
			ENDCG
		}
	}
}