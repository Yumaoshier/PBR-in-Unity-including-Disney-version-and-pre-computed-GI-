Shader "My PBR/Irradiance"
{
    Properties
    {
        _Skybox("Skybox", CUBE) = "" {}
        _SamplerDelta ("Smapler Delta", Range(0, 1)) = 0.1 //0.025
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

            struct appdata
            {
                float4 vertex : POSITION;
                
            };

            struct v2f
            {
                float4 vertex : TEXCOORD0;         
                float4 clipPos : SV_POSITION;
            };

            samplerCUBE _Skybox;
            float _SamplerDelta;

            v2f vert (appdata v)
            {
                v2f o;
                o.clipPos = UnityObjectToClipPos(v.vertex);
                o.vertex = v.vertex;           
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 irradiance = float3(0, 0, 0);
                float3 normal = normalize(i.vertex);
                float3 up = float3(0, 1, 0);
                float3 right = cross(up, normal);
                up = cross(right, normal);
                int nrSamples = 0;
                for (float phi = 0.0; phi < 2.0 * UNITY_PI; phi += _SamplerDelta) {
                    for (float theta = 0.0; theta < UNITY_PI * 0.5; theta += _SamplerDelta) {
                        // spherical to cartesian (in tangent space)
                        float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
                        //tangent to world space
                        float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normal;
                        irradiance += texCUBE(_Skybox, sampleVec).rgb * sin(theta) * cos(theta);
                        nrSamples++;
                    }
                }
                irradiance = UNITY_PI * irradiance / nrSamples;

                return float4(irradiance, 1);
            }
            ENDCG
        }
    }
}
