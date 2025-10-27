/* NOTES

    - add shadergrpah as dependency for nosie function (or steal the code)

*/

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
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
                float2 uv : TEXCOORD3;
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
                OUT.uv = IN.uv;
                return OUT;
            }

            inline float unity_noise_randomValue (float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233)))*43758.5453);
            }

            inline float unity_noise_interpolate (float a, float b, float t)
            {
                return (1.0-t)*a + (t*b);
            }

            inline float unity_valueNoise (float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = unity_noise_randomValue(c0);
                float r1 = unity_noise_randomValue(c1);
                float r2 = unity_noise_randomValue(c2);
                float r3 = unity_noise_randomValue(c3);

                float bottomOfGrid = unity_noise_interpolate(r0, r1, f.x);
                float topOfGrid = unity_noise_interpolate(r2, r3, f.x);
                float t = unity_noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float Unity_SimpleNoise_float(float2 UV, float Scale)
            {
                float t = 0.0;

                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3-0));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                return t;
            }

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
                float stepIn = lerpFinal + Unity_SimpleNoise_float(IN.uv, _NoiseScale);
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

                //END TEST

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
