Shader "Custom/GPUSnowFall"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "Queue"           = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType"      = "Transparent"
        }

        ZWrite Off
        Cull   Off
        Blend  SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM

            #pragma target   5.0
            #pragma vertex   vertexShader
            #pragma geometry geometryShader
            #pragma fragment fragmentShader

            #include "UnityCG.cginc"

            StructuredBuffer<float3> _VertexBuffer;
            StructuredBuffer<float>  _ScaleBuffer;

            float3 _OriginPosition;
            float3 _CameraUp;
            
            sampler2D _MainTex;
            float4    _MainTex_ST;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 position : SV_POSITION;
                float2 uv       : TEXCOORD0;
                half4  color    : TEXCOORD1;
                float  scale    : TESSFACTOR0;
            };

            float GetRandomNumber(float2 coord, int Seed)
            {
                return frac(sin(dot(coord.xy, float2(12.9898, 78.233)) + Seed) * 43758.5453);
            }

            // ------------------------------------------------------------------------------------
            // VertexShader
            // ------------------------------------------------------------------------------------

            vertexOutput vertexShader(uint vertexID : SV_VertexID)
            {
                vertexOutput output;
                
                half value = vertexID % 10 / 10.0;

                output.position = float4(_VertexBuffer[vertexID] + _OriginPosition, 1);
                output.color    = half4(value, value, value, 1);
                output.uv       = float2(0, 0);
                output.scale    = _ScaleBuffer[vertexID];

                return output;
            }

            // ------------------------------------------------------------------------------------
            // GeometryShader
            // ------------------------------------------------------------------------------------

            [maxvertexcount(4)]
            void geometryShader(point vertexOutput input[1],
                inout TriangleStream<vertexOutput> outputStream)
            {
                vertexOutput output;
                float4 position     = input[0].position;
                float4 color        = input[0].color;
                float  scale        = input[0].scale;
                float randomValue   = GetRandomNumber(position.xy, 0);

                for (int x = 0; x < 2; x++) 
                {
                    for (int y = 0; y < 2; y++) 
                    {
                        // ビルボードのメッシュを構成する 4 頂点になるようにする。

                        output.position = position + float4(float2(x, y) * 0.5 * scale, 0, 0);

                        // ビルボードの処理。
                        // ObjSpaceViewDir は、オブジェクト空間から見たカメラの方向を算出する関数です。

                        //float3 eyeVector   = normalize(ObjSpaceViewDir(output.position));
                        //float3 rightVector = normalize(cross(eyeVector, _CameraUp));
                        //output.position += float4((x - 0.5f) * rightVector, 0);
                        //output.position += float4((y - 0.5f) * _CameraUp, 0);

                        output.position = mul(UNITY_MATRIX_VP, output.position);
                        output.uv       = TRANSFORM_TEX(float2(x, y), _MainTex);
                        output.color    = color;
                        output.scale    = scale;

                        outputStream.Append(output);
                    }
                }

                outputStream.RestartStrip();
            }

            // ------------------------------------------------------------------------------------
            // FragmentShader
            // ------------------------------------------------------------------------------------

            fixed4 fragmentShader(vertexOutput input) : COLOR
            {
                //return input.color;

                fixed4 color = tex2D(_MainTex, input.uv);

                // 描画オブジェクトの前後関係が重要なときは、
                // ZWrite を有効にして、α で削る。
                //if (color.a < 0.3)
                //{
                //    discard;
                //}

                return color;
            }

            ENDCG
        }
    }
}