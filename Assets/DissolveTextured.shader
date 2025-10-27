Shader "Custom/DissolveTextured"
{
    Properties
    {
        _ObjectColor("ObjectColor", Color) = (1, 1, 1, 1)
        _GlowColor("GlowColor", Color) = (1, 1, 1, 1)
        _GlowStrength("GlowStrength", float) = 5
        _DissolvePointOS("DissolvePointOS", Vector) = (0.35, 0, 0.35)
        _DissolveRadiusOS("DissolveRadiusOS", float) = 1
        _DissolveProgress("DissolveProgress", float) = 0.5
        _GlowArea("GlowArea", float) = 0.1
        _NoiseScale("NoiseScale",  float) = 100
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            // Needed for transparent
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _ObjectColor;
                float4 _GlowColor;
                float _GlowStrength;
                float3 _DissolvePointOS;
                float _DissolveRadiusOS;
                float _DissolveProgress;
                float _GlowArea;
                float _NoiseScale;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionOS = IN.positionOS.xyz;
                return OUT;
            }

            // Simple Noise from ChatGPT
            float hash(float2 p)
            {
                // Create a pseudo-random number based on input
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * (p.x + p.y));
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                // Compute 4 corners
                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));

                // Smooth interpolation
                float2 u = f * f * (3.0 - 2.0 * f);

                // Bilinear interpolation
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            float SimpleNoise(float2 uv, float scale)
            {
                return noise(uv * scale);
            }
            //End ChatGPT


            half4 frag(Varyings IN) : SV_Target
            {
                Light mainLight = GetMainLight();

                // Begin Dissolve

                //weird
                float lerpWeird = lerp(0.15, 0.85, _DissolveProgress);

                //lerp a
                float lerpA = lerp(1, -3, lerpWeird);
                clamp(lerpA, -1, 1);

                //lerp b
                float lerpB = lerp(3, -1, lerpWeird);
                clamp(lerpB, -1, 1);

                //lerp t
                float distanceOS = length(_DissolvePointOS - IN.positionOS);
                float lerpT = distanceOS / _DissolveRadiusOS;
                
                //lerp final
                float lerpFinal = lerp(lerpA, lerpB, lerpT);

                //alpha calculation
                float stepIn = lerpFinal + SimpleNoise(IN.normalWS, _NoiseScale);
                float finalAlpha = stepIn > 0.5? 1 : 0;

                // End Dissolve

                // Compute normal lighting
                float3 N = normalize(IN.normalWS);
                float NdotL = saturate(dot(N, mainLight.direction));

                // Recieve shadows
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half shadowAtten = MainLightRealtimeShadow(shadowCoord);

                // Apply shadow to lighting
                float3 litColor = _ObjectColor.rgb * mainLight.color * NdotL * shadowAtten;

                //Emission
                litColor += _GlowColor;

                return half4(litColor, finalAlpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragShadowCaster

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 posHCS : SV_POSITION;
                float3 positionOS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.posHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionOS = IN.positionOS.xyz;
                return OUT;
            }

            float4 fragShadowCaster(Varyings IN) : SV_Target
            {
                float3 dissPointOS = float3(0.35,0,0.35);
                float dissProgress = 0.5;
                float dissRadiusOS = 1;
                float dist = length(IN.positionOS - dissPointOS);
                float alpha = (dist < lerp(0,dissRadiusOS,dissProgress)) ? 0 : 1;

                clip(alpha - 0.1);
                return 0;
            }
            ENDHLSL
        }
    }
}
