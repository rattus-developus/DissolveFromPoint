Shader "Custom/DissolveHLSL"
{
    Properties
    {
        [Header(URP Lit Properties)]
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _Occlusion ("Occlusion", Range(0,1)) = 0.5
        [HDR] _Emission ("Emission", Color) = (0, 0, 0, 0)

        [Header(Dissolve Properties)]
        _DissolvePointOS("DissolvePointOS", Vector) = (0.35, 0, 0.35)
        _DissolveRadiusOS("DissolveRadiusOS", float) = 1
        _DissolveProgress("DissolveProgress", Range(0, 1)) = 0.5
        _DistanceWeight("DistanceWeight", Range(0, 1)) = 0.375
        _NoiseScale("NoiseScale",  float) = 100

        [Header(Dissolve Glow Properties)]
        _GlowColor("GlowColor", Color) = (1, 0, 0, 1)
        _GlowStrength("GlowStrength", float) = 5
        _GlowArea("GlowArea", Range(0, 1)) = 0.025
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Blend Off
            ZWrite On

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #include "Packages/com.unity.visualeffectgraph/Shaders/VFXNoise.hlsl"
            
            //Lit Properties
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;
            float4 _Emission;
            float4 _BaseColor;
            float _Metallic;
            float _Smoothness;
            float _Occlusion;

            //Dissolve Properties
            float4 _GlowColor;
            float _GlowStrength;
            float3 _DissolvePointOS;
            float _DissolveRadiusOS;
            float _DissolveProgress;
            float _GlowArea;
            float _NoiseScale;
            float _DistanceWeight;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float2 uv          : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                half fogCoord      : TEXCOORD4;
                float3 positionOS  : TEXCOORD5;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;

                VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs normInputs = GetVertexNormalInputs(v.normalOS);

                o.positionCS = posInputs.positionCS;
                o.positionWS = posInputs.positionWS;
                o.positionOS = v.positionOS.xyz;
                o.normalWS   = normInputs.normalWS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

                o.shadowCoord = GetShadowCoord(posInputs);
                o.fogCoord = ComputeFogFactor(o.positionCS.z);

                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                //--------Unity URP Lit--------//
                //Set up surface data for urp lit
                //SurfaceData initialization values taken from Lighting.hlsl UniversalFragmentPBR
                SurfaceData surfaceData;

                surfaceData.albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb * _BaseColor.rgb;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = _Smoothness;
                surfaceData.alpha = _BaseColor.a; 
                surfaceData.emission = _Emission.xyz;
                surfaceData.occlusion = _Occlusion; 
                
                surfaceData.specular = half3(0, 0, 0); // ignore, using metallic
                surfaceData.clearCoatMask = 0;
                surfaceData.clearCoatSmoothness = 1;
                surfaceData.normalTS = half3(0, 0, 1);
                
                //Set up input data for urp lit
                InputData inputData;

                inputData.positionWS = i.positionWS;
                inputData.normalWS = normalize(i.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                inputData.shadowCoord = i.shadowCoord;
                inputData.fogCoord = i.fogCoord;
                inputData.vertexLighting = half3(0,0,0); // not using per-vertex lights (for now)
                inputData.bakedGI = SampleSH(inputData.normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
                inputData.shadowMask = half4(1,1,1,1); // not using baked shadows (for now)



                //--------Dissolve Effect--------//
                //_DissolveProgress = abs(_SinTime.z); // Sine wave dissolve progress for demo purposes
                float noise0to1 = (GeneratePerlinNoise3D(i.positionOS * _NoiseScale).x + 1) / 2; //using position-based 3D noise rather than uv-based 2D noise to prevent UV edge artifacts
                noise0to1 = lerp(_DistanceWeight, 1, noise0to1); // remap the noise values to give more weight to the distance factor

                //Interpolate alpha based on noise and distance
                float distanceOS = length(_DissolvePointOS - i.positionOS);
                float distanceFactor = distanceOS / _DissolveRadiusOS;
                float finalAlpha = (noise0to1 + 0.00001) - (_DissolveProgress / distanceFactor);
                
                clip(finalAlpha); // if finalAlpha < 0, discard

                float glow = finalAlpha - _GlowArea < 0? 1: 0;
                float power = _GlowStrength * glow;

                half3 color = UniversalFragmentPBR(inputData, surfaceData).xyz;
                color += power * _GlowColor.rgb;

                color = MixFog(color, i.fogCoord);
                return half4(color, 1); // 1 for alpha is fine since we are clipping
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
            #pragma multi_compile_shadowcaster


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #include "Packages/com.unity.visualeffectgraph/Shaders/VFXNoise.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posHCS : SV_POSITION;
                float3 positionOS : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            float3 _DissolvePointOS;
            float _DissolveRadiusOS;
            float _DissolveProgress;
            float _NoiseScale;
            float _DistanceWeight;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS   = TransformObjectToWorldNormal(IN.normalOS);

                // Directional light only (URP shadow maps)
                float3 lightDirWS = _MainLightPosition.xyz;

                // URP shadow-bias (prevents weird shadow artifacts/self-shadowing)
                positionWS = ApplyShadowBias(positionWS, normalWS, lightDirWS);
                positionWS -= normalWS * 0.001;

                OUT.posHCS = TransformWorldToHClip(positionWS);

                OUT.positionOS = IN.positionOS.xyz;
                OUT.uv = IN.uv;
                return OUT;
            }
            
            float4 fragShadowCaster(Varyings IN) : SV_Target
            {
                // mimic dissolve
                //_DissolveProgress = abs(_SinTime.z); // Sine wave dissolve progress for demo purposes
                float noise0to1 = (GeneratePerlinNoise3D(IN.positionOS * _NoiseScale).x + 1) / 2;
                noise0to1 = lerp(_DistanceWeight, 1, noise0to1);
                float distanceOS = length(_DissolvePointOS - IN.positionOS);
                float distanceFactor = distanceOS / _DissolveRadiusOS;
                float finalAlpha = (noise0to1 + 0.00001) - (_DissolveProgress / distanceFactor);
                
                float alpha = step(0.5, finalAlpha);
                clip(finalAlpha);
                return 0;
            }
            ENDHLSL
        }

    }
}
