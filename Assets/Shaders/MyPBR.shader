Shader "My PBR/MyPBR"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        [Gamma] _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _LUT ("LUT", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {   NAME "FORWARD"
            Tags{
            "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile_fwdbase_fullshadows

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            //#include "UnityStandardBRDF.cginc"
            //LIGHTING_COORDS    TRANSFER_VERTEX_TO_FRAGMENT
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;    //lightmap uv coordinates
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;     //lightmap uv coordinates
                float3 normal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Tint;
            float _Metallic;
            float _Smoothness;
            sampler2D _LUT;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.normal = normalize(o.normal);
                o.uv1 = v.uv1;
                return o;
            }

            float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
                return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);
                float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));  //? - i.worldPos.xyz
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float3 lightColor = _LightColor0.rgb;
                float3 halfVector = normalize(lightDir + viewDir);
                float3 lightDis = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);

                float perceptualRoughness = 1.0 - _Smoothness;
                float roughness = perceptualRoughness * perceptualRoughness;
                float squareRoughness = roughness * roughness;

                float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);
                float nv = max(saturate(dot(i.normal, viewDir)), 0.000001);
                float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
                float nh = max(saturate(dot(i.normal, halfVector)), 0.000001);
                float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);

                
                float3 Albedo = _Tint * tex2D(_MainTex, i.uv);
                
                //directLight Specular
                float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2.0);
                float D = lerpSquareRoughness / (pow(pow(nh, 2.0) * (lerpSquareRoughness - 1.0) + 1.0, 2.0) * UNITY_PI);
                float kDirect = pow(roughness + 1.0, 2.0) / 8.0;  //roughness
                float kIBL = lerpSquareRoughness / 2.0;
                //float G = (nv / (nv * (1 - kDirect) + kDirect)) * (nl / (nl * (1 - kDirect) + kDirect));
                //float G = (nv / lerp(nv, 1, kDirect)) * (nl / lerp(nl, 1, kDirect));
                float G = (1.0 / lerp(nv, 1, kDirect)) * (1.0 / lerp(nl, 1, kDirect));    //nv, nl can be delected by the whole formula 'ks/4 * (DGF/(nv * nl))'
                float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, _Metallic);
                float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);
                //float ks = 1;   //ks is the same as the F, so can be deleted
                float3 specular = (D * G * F * 0.25) * lightColor * nl * UNITY_PI;   //* UNITY_PI， since there is no divide by UNITY_PI in diffuse, so there is multipy UNITY_PI to instead

                //directLight Diffuse
                float kd = (1 - F) * (1 - _Metallic);
                float3 diffuse = kd * Albedo * lightColor * nl;

                float3 directLight = diffuse + specular;

                //GI Diffuse
                half3 ambient_integration = ShadeSH9(float4(i.normal, 1));
                float3 ambient = 0.03 * Albedo;
                float3 iblDiffuse = max(half3(0, 0, 0), ambient_integration + ambient);
                float3 F_ibl = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);
                float kd_ibl = (1 - F_ibl) * (1 - _Metallic);
                float3 indiffuse = kd_ibl * Albedo * iblDiffuse;
                //GI Specular
                //prefilter cubemap
                float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
                float3 reflectVector = reflect(-viewDir, i.normal);
                half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
                float3 prefilter_Specular = DecodeHDR(rgbm, unity_SpecCube0_HDR);
                //envBRDF IBL
                float2 envBRDF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg;   //nv 而不是 nl

                float3 inspecular = prefilter_Specular * (envBRDF.r * F_ibl + envBRDF.g);
                float3 indirectLight = indiffuse + inspecular;  //

                float4 col = float4(directLight + indirectLight, 1);//
                return col;
            }
            ENDCG
        }
        Pass
        {
            Tags{
            "LightMode" = "ForwardAdd"
            }
            ZWrite Off Blend One One Fog {Color (0, 0, 0, 0)}

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase

            #include "UnityStandardBRDF.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Tint;
            float _Metallic;
            float _Smoothness;
            sampler2D _LUT;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.normal = normalize(o.normal);
                return o;
            }

            float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
                return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);
                float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));  //? - i.worldPos.xyz
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float3 lightColor = _LightColor0.rgb;
                float3 halfVector = normalize(lightDir + viewDir);
                float3 lightDis = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);

                float perceptualRoughness = 1.0 - _Smoothness;
                float roughness = perceptualRoughness * perceptualRoughness;
                float squareRoughness = roughness * roughness;

                float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);
                float nv = max(saturate(dot(i.normal, viewDir)), 0.000001);
                float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
                float nh = max(saturate(dot(i.normal, halfVector)), 0.000001);
                float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);


                float3 Albedo = _Tint * tex2D(_MainTex, i.uv);

                //directLight Specular
                float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2.0);
                float D = lerpSquareRoughness / (pow(pow(nh, 2.0) * (lerpSquareRoughness - 1.0) + 1.0, 2.0) * UNITY_PI);
                float kDirect = pow(roughness + 1.0, 2.0) / 8.0;  //roughness
                float kIBL = lerpSquareRoughness / 2.0;
                //float G = (nv / (nv * (1 - kDirect) + kDirect)) * (nl / (nl * (1 - kDirect) + kDirect));
                //float G = (nv / lerp(nv, 1, kDirect)) * (nl / lerp(nl, 1, kDirect));
                float G = (1.0 / lerp(nv, 1, kDirect)) * (1.0 / lerp(nl, 1, kDirect));    //nv, nl can be delected by the whole formula 'ks/4 * (DGF/(nv * nl))'
                float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, _Metallic);
                float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);
                //float ks = 1;   //ks is the same as the F, so can be deleted
                float3 specular = (D * G * F * 0.25) * lightColor * nl * UNITY_PI;   //* UNITY_PI， since there is no divide by UNITY_PI in diffuse, so there is multipy UNITY_PI to instead

                //directLight Diffuse
                float kd = (1 - F) * (1 - _Metallic);
                float3 diffuse = kd * Albedo * lightColor * nl;

                float3 directLight = diffuse + specular;

                //GI Diffuse
                half3 ambient_integration = ShadeSH9(float4(i.normal, 1));
                float3 ambient = 0.03 * Albedo;
                float3 iblDiffuse = max(half3(0, 0, 0), ambient_integration + ambient);
                float3 F_ibl = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);
                float kd_ibl = (1 - F_ibl) * (1 - _Metallic);
                float3 indiffuse = kd_ibl * Albedo * iblDiffuse;
                //GI Specular
                //prefilter cubemap
                float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
                float3 reflectVector = reflect(-viewDir, i.normal);
                half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
                float3 prefilter_Specular = DecodeHDR(rgbm, unity_SpecCube0_HDR);
                //envBRDF IBL
                float2 envBRDF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg;   //nv 而不是 nl

                float3 inspecular = prefilter_Specular * (envBRDF.r * F_ibl + envBRDF.g);
                float3 indirectLight = indiffuse + inspecular;  //

                float4 col = float4(directLight + indirectLight, 1);//
                return col;
            }
            ENDCG
        }
    }
}
