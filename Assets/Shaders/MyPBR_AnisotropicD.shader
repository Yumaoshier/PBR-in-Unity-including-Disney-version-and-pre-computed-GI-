// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "My PBR/MyPBRAnisoD"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        [Gamma] _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _LUT ("LUT", 2D) = "white" {}
        _Anisotropic ("Anisotropic", Range(0, 1)) = 0
        _IrradianceMap("Irradiance Map", CUBE) = "white" {}
        _PrefilterMap("Prefilter Map", CUBE) = "white" {}
        _AO("AO", Range(0, 1)) = 1
    }
    CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        #include "Common/brdf.hlsl"
        //#define UNITY_PASS_FORWARDBASE

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;    //lightmap uv coordinates
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };

        

        sampler2D _MainTex;
        float4 _MainTex_ST;
        float4 _Tint;
        float _Metallic;
        float _Smoothness;
        sampler2D _LUT;
        float _Anisotropic;
        samplerCUBE _IrradianceMap;
        samplerCUBE _PrefilterMap;
        float _AO;

    
       
        struct v2f
        {
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;     //lightmap uv coordinates
            float3 normal : TEXCOORD2;
            float3 worldPos : TEXCOORD3;
            float3 tangentDir : TEXCOORD4;
            float3 bitangentDir : TEXCOORD5;
            float3 vertexLight : TEXCOORD6;
            float4 pos : SV_POSITION;
            LIGHTING_COORDS(7, 8)

        };



        fixed4 frag(v2f i) : SV_Target
        {
            i.normal = normalize(i.normal);
            float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));  //? - i.worldPos.xyz
            
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
            float attenuation = 1;
            
            if (_WorldSpaceLightPos0.w == 0) {
                attenuation = 1;
            }
            else {              
                float lightDis = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                attenuation = 1 / (lightDis * lightDis);
            }
            //attenuation = LIGHT_ATTENUATION(i);  //this will result the directional light have attenuation
            
            
            float3 lightColor = _LightColor0.rgb * attenuation;  //
            float3 halfVector = normalize(lightDir + viewDir);
            

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
            //float D = lerpSquareRoughness / (pow(pow(nh, 2.0) * (lerpSquareRoughness - 1.0) + 1.0, 2.0) * UNITY_PI);
            //TrowbridgeReitzAnisotropicNormalDistribution will result when there is no directional light, the object will be totally dark
            float D = TrowbridgeReitzAnisotropicNormalDistribution(_Anisotropic, nh, dot(halfVector, i.tangentDir), dot(halfVector, i.bitangentDir), roughness);

            float kDirect = pow(roughness + 1.0, 2.0) / 8.0;  //roughness
          
            float G = (1.0 / lerp(nv, 1, kDirect)) * (1.0 / lerp(nl, 1, kDirect));    //nv, nl can be delected by the whole formula 'ks/4 * (DGF/(nv * nl))'
            float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, _Metallic);
            float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);  //Spherical Gaussian Fresenl
            
            float3 specular = (D * G * F * 0.25);   // * UNITY_PI， since there is no divide by UNITY_PI in diffuse, so there is multipy UNITY_PI to instead

            //directLight Diffuse
            //float kd = (1 - F) * (1 - _Metallic);                 //by metallic
            float kd = DisneyDiffuse_kd(roughness, nv, nl, vh);     //by roughness
            float3 diffuse = kd * Albedo / UNITY_PI;  // 

            float3 directLight = (diffuse + specular) * lightColor * nl;

            //GI Diffuse          
            float3 F_ibl = fresnelSchlickRoughness(nv, F0, roughness);   //perceptualRoughness
            float kd_ibl = (1 - F_ibl) * (1 - _Metallic);   //
            float3 irradiance = texCUBE(_IrradianceMap, i.normal).rgb;
            float3 indiffuse = kd_ibl * Albedo * irradiance;
            //GI Specular
            //prefilter cubemap
            float3 reflectVector = reflect(-viewDir, i.normal);
            float3 prefilter_Specular = texCUBE(_PrefilterMap, reflectVector).rgb;
            //envBRDF IBL
            float2 envBRDF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg;   

            float3 inspecular = prefilter_Specular * (envBRDF.r * F_ibl + envBRDF.g);
            float3 indirectLight = (indiffuse + inspecular) * _AO;
   
            float4 col = float4(directLight + indirectLight + i.vertexLight, 1);
            return col;
        }


    ENDCG

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

           
            //#include "UnityStandardBRDF.cginc"
            //LIGHTING_COORDS    TRANSFER_VERTEX_TO_FRAGMENT
           
            
            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.normal = normalize(o.normal);
                o.uv1 = v.uv1;
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
    #ifdef LIGHTMAP_OFF
                float3 shLight = ShadeSH9(float4(o.normal, 1.0));
                o.vertexLight = shLight;
    #ifdef VERTEXLIGHT_ON
                float3 vertexLight = Shade4PointLights(unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0, unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb,
                    unity_LightColor[3].rgb, unity_4LightAtten0, o.worldPos, o.normal);
                o.vertexLight += vertexLight;
    #endif
    #endif
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
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

            #pragma multi_compile_fwdadd
            

            //#include "UnityStandardBRDF.cginc"
            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.normal = normalize(o.normal);
                o.uv1 = v.uv1;
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
                
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            
            ENDCG
        }
    }
}
