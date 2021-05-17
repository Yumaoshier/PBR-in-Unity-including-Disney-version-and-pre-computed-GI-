Shader "My PBR/LUT"
{
    Properties
    {
       
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

            #include "../Common/brdf.hlsl"
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;

                float4 vertex : SV_POSITION;
            };

           

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                return o;
            }

            

            float GeometrySchlickGGX(float nv, float roughness)
            {
               
                float k = (roughness * roughness) / 2.0;

                float nom = nv;
                float denom = nv * (1.0 - k) + k;

                return nom / denom;
            }

            float GeometrySmith(float nv, float nl, float roughness) {
                return GeometrySchlickGGX(nv, roughness) * GeometrySchlickGGX(nl, roughness);
            }

            float2 IntegrateBRDF(float nv, float roughness) {
                float3 V;
                V.x = sqrt(1.0 - nv * nv);
                V.y = 0;
                V.z = nv;
                float A = 0.0;
                float B = 0.0;
                float3 N = float3 (0.0, 0.0, 1.0);
             
                const uint SAMPLE_COUNT = 1024u;
                for (uint i = 0u; i < SAMPLE_COUNT; i++) {
                    float2 Xi = Hammersley(i, SAMPLE_COUNT);
                    float3 H = ImportanceSampleGGX(Xi, N, roughness);
                    float3 L = normalize(2.0 * dot(V, H) * H - V);
                    float nl = max(L.z, 0.0);
                    float nh = max(H.z, 0.0);
                    float vh = max(dot(V, H), 0.0);
                    if (nl > 0.0)
                    {
                        float G = GeometrySmith(nv, nl, roughness);
                        float G_Vis = (G * vh) / (nh * nv);
                        float Fc = pow(1.0 - vh, 5.0);

                        A += (1.0 - Fc) * G_Vis;
                        B += Fc * G_Vis;
                    }
                }
                A /= float(SAMPLE_COUNT);
                B /= float(SAMPLE_COUNT);
                return float2(A, B);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                fixed2 col = IntegrateBRDF(i.uv.x, i.uv.y);
            
                return float4(col, 0, 1);
            }
            ENDCG
        }
    }
}
