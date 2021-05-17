// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "My PBR/MyPBRDisneyTex"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Tint("Tint", Color) = (1, 1, 1, 1)
        _Normal ("Normal Map", 2D) = "bump" {}

        _Metal ("Metal Map", 2D) = "bump" {}
        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        _Roughness ("Roughness Map", 2D) = "bump" {}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _LUT("LUT", 2D) = "white" {}
        _Anisotropic("Anisotropic", Range(0, 1)) = 0
        _Subsurface("Subsurface", Range(0, 1)) = 0
        _Specular("Specular", Range(0, 1)) = 0.5
        _SpecularTint("SpecularTint", Range(0, 1)) = 0  //--
        _Sheen("Sheen", Range(0, 1)) = 0
        _SheenTint("SheenTint", Range(0, 1)) = 0.5  //--
        _Clearcoat("Clearcoat", Range(0, 1)) = 0
        _ClearcoatGloss("ClearcoatGloss", Range(0, 1)) = 1
        _IrradianceMap("Irradiance Map", CUBE) = "white" {}
        _PrefilterMap ("Prefilter Map", CUBE) = "white" {}     
     
        _AOMap ("AO Map", 2D) = "bump" {}
        _AO("AO", Range(0, 1)) = 1

    }
    CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        #include "Common/brdf.hlsl"
        //#include "UnityStandardBRDF.cginc"
        //#define UNITY_PASS_FORWARDBASE

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;         
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };

        

        sampler2D _MainTex;
        float4 _MainTex_ST;
        float4 _Tint;
        sampler2D _Normal;
        float4 _Normal_ST;
        sampler2D _Metal;
        float _Metallic;
        sampler2D _Roughness;
        float4 _Roughness_ST;
        float _Smoothness;
        sampler2D _LUT;
        float _Anisotropic;
        float _Subsurface;
        float _Specular;
        float _SpecularTint;
        float _Sheen;
        float _SheenTint;
        float _Clearcoat;
        float _ClearcoatGloss;
        samplerCUBE _IrradianceMap;
        samplerCUBE _PrefilterMap;        
        sampler2D _AOMap;
        float4 _AOMap_ST;
        float _AO;
       
        //Fs
        float3 Specular_Fresnel(float3 Ctint, float3 Cdlin, float Flh, float metallic) {
            float3 F0 = lerp(_Specular * 0.08 * lerp(float3(1, 1, 1), Ctint, _SpecularTint), Cdlin, metallic);
            float3 F = lerp(F0, float3(1, 1, 1), Flh);
            return F;
        }
        
        float3 PBR4PointLights(float3 worldPos, float3 normal, float3 tangentDir, float3 bitangentDir, float ax, float ay, float roughness,
            float3 Albedo, float3 Ctint, float3 Csheen, float metallic)
        {          
            float3 directLight = 0;
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);        
            for (int i = 0; i < 4; i++) {
                float3 lightPos = float3(unity_4LightPosX0[i], unity_4LightPosY0[i], unity_4LightPosZ0[i]);
                float3 lightDir = lightPos - worldPos;
                float lightDis = length(lightDir);
                lightDir = normalize(lightDir);
                float3 halfVector = normalize(lightDir + viewDir);
                float atten = 1.0 / (1.0 + unity_4LightAtten0[i] * lightDis * lightDis);
                float3 lightColor = unity_LightColor[i].rgb * atten;
                float nl = max(saturate(dot(normal, lightDir)), 0.000001);
                float nv = max(saturate(dot(normal, viewDir)), 0.000001);
                float nh = max(saturate(dot(normal, halfVector)), 0.000001);
                float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);
                float hx = dot(halfVector, tangentDir);
                float hy = dot(halfVector, bitangentDir);

                float Fnl = SchlickFresnel(nl);
                float Fnv = SchlickFresnel(nv);
                float Flh = SchlickFresnel(lh);

                //directLight Specular
                float Ds = Disney_Specular_GTR2_aniso(hx, hy, nh, ax, ay);
                //float Ds = Disney_Specular_GTR2_iso(nh, roughness); 
                float Gnv = SmithsG_GGX_aniso(nv, dot(viewDir, hx), dot(viewDir, hy), ax, ay);    // 2 * 2, nv, nl can be delected by the whole formula 'ks/4 * (DGF/(nv * nl))'
                float Gnl = SmithsG_GGX_aniso(nl, dot(lightDir, hx), dot(lightDir, hy), ax, ay);
                float Gs = Gnv * Gnl; 
                float3 Fs = Specular_Fresnel(Ctint, Albedo, Flh, metallic); 

                float Dr = Disney_Clear_GTR1(nh, lerp(0.1, 0.001, _ClearcoatGloss));
                float3 F0 = float3(0.04, 0.04, 0.04);
                float3 Fr = lerp(F0, float3(1, 1, 1), Flh);
                float Gr = Disney_Clear_GGX(nv, nl, 0.25);

                float3 specular = Gs * Fs * Ds + Dr * Gr * Fr * _Clearcoat * 0.25; 

                //directLight Diffuse
                float Fd = Disney_Diffuse_Kfd(roughness, lh, Fnl, Fnv);
                float ss = Disney_Subsurface_ss(roughness, lh, Fnl, Fnv, nl, nv);
                float3 Fsheen = Flh * _Sheen * Csheen;

                float3 diffuse = (Albedo / UNITY_PI * lerp(Fd, ss, _Subsurface) + Fsheen) * (1.0 - metallic);  //

                directLight += (diffuse + specular) * lightColor * nl;
            }
            
            return directLight;
        }
     

        struct v2f
        {
            float2 uv : TEXCOORD0;         
            float3 normal : TEXCOORD1;
            float3 worldPos : TEXCOORD2;
            float3 tangentDir : TEXCOORD3;
            float3 bitangentDir : TEXCOORD4;
            float3 vertexLight : TEXCOORD5;
            float4 pos : SV_POSITION;
            LIGHTING_COORDS(6, 7)

        };

        fixed4 frag(v2f i) : SV_Target
        {
            float3 tanNormal = UnpackNormal(tex2D(_Normal, TRANSFORM_TEX(i.uv, _Normal)));
            float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normal);           
            i.normal = normalize(mul(tanNormal, tangentTransform));

            float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));           
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
            float attenuation = 1;
            
            if (_WorldSpaceLightPos0.w == 0) {
                attenuation = 1;
            }
            else {              
                float lightDis = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                attenuation = 1 / (lightDis * lightDis);            
            }
            
            float3 lightColor = _LightColor0.rgb * attenuation; 
            float3 halfVector = normalize(lightDir + viewDir);

            float metallic = tex2D(_Metal, i.uv) * _Metallic;
     
            float perceptualRoughness = tex2D(_Roughness, TRANSFORM_TEX(i.uv, _Roughness)).x * (1.0 - _Smoothness);
            float roughness = perceptualRoughness * perceptualRoughness;
            float squareRoughness = roughness * roughness;

            float ao = tex2D(_AOMap, TRANSFORM_TEX(i.uv, _AOMap)).x * _AO;

            float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);
            float nv = max(saturate(dot(i.normal, viewDir)), 0.000001);
            float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
            float nh = max(saturate(dot(i.normal, halfVector)), 0.000001);
            float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);

            float aspect = sqrt(1.0 - _Anisotropic * 0.9);
            float ax = max(0.001, squareRoughness / aspect);
            float ay = max(0.001, squareRoughness * aspect);
            float hx = max(saturate(dot(halfVector, i.tangentDir)), 0.000001);
            float hy = max(saturate(dot(halfVector, i.bitangentDir)), 0.000001);

            float3 Albedo = _Tint * tex2D(_MainTex, i.uv);
           
            float Cdlum = 0.3 * Albedo.r + 0.6 * Albedo.g + 0.1 * Albedo.b;
            float3 Ctint = Cdlum > 0 ? (Albedo / Cdlum) : float3(1, 1, 1);
            float3 Csheen = lerp(float3(1, 1, 1), Ctint, _SheenTint);

            float Fnl = SchlickFresnel(nl);
            float Fnv = SchlickFresnel(nv);
            float Flh = SchlickFresnel(lh);

            //directLight Specular
            //float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2.0);
            //float Ds = lerpSquareRoughness / (pow(pow(nh, 2.0) * (lerpSquareRoughness - 1.0) + 1.0, 2.0) * UNITY_PI);
            //float Ds = Disney_Specular_GTR2_aniso(hx, hy, nh, ax, ay);
            float Ds = Disney_Specular_GTR2_iso(nh, roughness); 

            float Gnv = SmithsG_GGX_aniso(nv, dot(viewDir, hx), dot(viewDir, hy), ax, ay);    //nv, nl can be delected by the whole formula 'ks/4 * (DGF/(nv * nl))'
            float Gnl = SmithsG_GGX_aniso(nl, dot(lightDir, hx), dot(lightDir, hy), ax, ay);
            //float kDirect = pow(roughness + 1.0, 2.0) / 8.0;  //roughness
            float Gs = Gnv * Gnl;
            //float Gs = (1.0 / lerp(nv, 1, kDirect)) * (1.0 / lerp(nl, 1, kDirect)) * 0.25;
  
            float3 Fs = Specular_Fresnel(Ctint, Albedo, Flh, metallic);  

            float Dr = Disney_Clear_GTR1(nh, lerp(0.1, 0.001, _ClearcoatGloss));
            float3 F0 = float3(0.04, 0.04, 0.04);
            float3 Fr = lerp(F0, float3(1, 1, 1), Flh);  //unity_ColorSpaceDielectricSpec.rgb
            float Gr = Disney_Clear_GGX(nv, nl, 0.25);
            
            float3 specular = Gs * Fs * Ds + Dr * Gr * Fr * 0.25 * _Clearcoat;   //* UNITY_PI， since there is no divide by UNITY_PI in diffuse, so there is multipy UNITY_PI to instead
           
            //directLight Diffuse
            //float kd = (1 - Fs) * (1 - metallic);                 //by metallic
            //float kd = DisneyDiffuse_kd(roughness, nv, nl, vh);     //by roughness
            float Fd = Disney_Diffuse_Kfd(roughness, lh, Fnl, Fnv);
            float ss = Disney_Subsurface_ss(roughness, lh, Fnl, Fnv, nl, nv);
            float3 Fsheen = Flh * _Sheen * Csheen;
            //float3 diffuse = kd * Albedo; Cdlin
            float3 diffuse = (Albedo * lerp(Fd, ss, _Subsurface) / UNITY_PI + Fsheen) * (1.0 - metallic); //

            float3 directLight = (diffuse + specular) * lightColor * nl;
            
    #ifdef VERTEXLIGHT_ON
            i.vertexLight = PBR4PointLights(i.worldPos.xyz, i.normal, i.tangentDir, i.bitangentDir, ax, ay, roughness, Albedo, Ctint, Csheen, metallic);
    #endif

            //directLight += i.vertexLight;

            //GI Diffuse             
            F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, metallic);
            float3 F_ibl = fresnelSchlickRoughness(nv, F0, roughness);   //perceptualRoughness
            float kd_ibl = (1 - F_ibl) * (1 - metallic);  
            float3 irradiance = texCUBE(_IrradianceMap, i.normal).rgb;
            float3 indiffuse = kd_ibl * Albedo * irradiance;
            
            //GI Specular
            //prefilter cubemap
            
            float3 reflectVector = reflect(-viewDir, i.normal);
     
            float3 prefilter_Specular = texCUBE(_PrefilterMap, reflectVector).rgb;
            //envBRDF IBL
            float2 envBRDF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg;   //nv 而不是 nl

            float3 inspecular = prefilter_Specular * (envBRDF.r * F_ibl + envBRDF.g);
            float3 indirectLight = (indiffuse + inspecular) * ao;

            float4 col = float4(directLight + indirectLight + i.vertexLight, 1);
   
            return col;
        }

        fixed4 frag_add(v2f i) : SV_Target
        {
            float3 tanNormal = UnpackNormal(tex2D(_Normal, TRANSFORM_TEX(i.uv, _Normal)));
            float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normal);
            i.normal = normalize(mul(tanNormal, tangentTransform));
            float metallic = tex2D(_Metal, i.uv) * _Metallic;

            float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
            float attenuation = 1;

            if (_WorldSpaceLightPos0.w == 0) {
                attenuation = 1;
            }
            else {
                float lightDis = length(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                attenuation = 1 / (lightDis * lightDis);
            }

            float3 lightColor = _LightColor0.rgb * attenuation;

            float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);

            float perceptualRoughness = tex2D(_Roughness, TRANSFORM_TEX(i.uv, _Roughness)).x * (1.0 - _Smoothness);          
            float roughness = perceptualRoughness * perceptualRoughness;
            float squareRoughness = roughness * roughness;
            float aspect = sqrt(1.0 - _Anisotropic * 0.9);
            float ax = max(0.001, squareRoughness / aspect);
            float ay = max(0.001, squareRoughness * aspect);
            float3 Albedo = _Tint * tex2D(_MainTex, i.uv);         
            float Cdlum = 0.3 * Albedo.r + 0.6 * Albedo.g + 0.1 * Albedo.z;
            float3 Ctint = Cdlum > 0 ? Albedo / Cdlum : float3(1, 1, 1);
            float3 Csheen = lerp(float3(1, 1, 1), _Tint.rgb, _SheenTint);

            float3 directLight = PBR4PointLights(i.worldPos.xyz, i.normal, i.tangentDir, i.bitangentDir, ax, ay, roughness, Albedo, Ctint, Csheen, metallic);
            directLight *= lightColor * nl;
            float4 col = float4(directLight, 1);//+ indirectLight
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

            //#include "AutoLight.cginc"
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
         
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            
            ENDCG
        }
    }
}
