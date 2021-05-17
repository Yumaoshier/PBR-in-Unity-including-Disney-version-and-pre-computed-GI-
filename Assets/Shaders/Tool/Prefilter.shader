Shader "My PBR/Prefilter"
{
    Properties
    {
        _Skybox ("Skybox", CUBE) = "white" {}
        _Roughness ("Roughness", Range(0, 1)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
    
            #include "UnityCG.cginc"
            #include "../Common/brdf.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
               
            };

            struct v2f
            {
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
            };

            samplerCUBE _Skybox;
            float _Roughness;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = v.vertex.xyz;
           
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.normal);
                float3 R = N;
                float3 V = R;

                const uint SAMPLE_COUNT = 1024u;
                float totalWeight = 0.0;
                float3 filterColor = float3(0.0, 0.0, 0.0);
                for (uint i = 0u; i < SAMPLE_COUNT; i++) {
                    float2 Xi = Hammersley(i, SAMPLE_COUNT);
                    float3 H = ImportanceSampleGGX(Xi, N, _Roughness);
                    float3 L = normalize(2.0 * dot(V, H) * H - V);
                    float nl = max(dot(N, L), 0.0);
                    if (nl > 0) {
                        float nh = max(dot(N, H), 0.0);
                        float hv = max(dot(H, V), 0.0);
                        float D = NormalDistributionF_PreFilter(nh, _Roughness);

                        //sample the cubemap based on pdf and roughness
                        float pdf = D * nh / (4.0 * hv) + 0.0001;
                        const float resolution = 512.0;   //resolution of the cubemap
                        const float texel = 4.0 * UNITY_PI / (6.0 * resolution * resolution);
                        float sasample = 1.0 / (float(SAMPLE_COUNT) * pdf + 0.0001);
                        float mipmap = _Roughness == 0.0 ? 0.0 : 0.5 * log2(sasample / texel);

                        filterColor += texCUBElod(_Skybox, half4(L, mipmap)).rgb * nl;
                        totalWeight += nl;
                    }
                }
                filterColor /= totalWeight;
        
                return float4(filterColor, 1);
            }
            ENDCG
        }
    }
}
