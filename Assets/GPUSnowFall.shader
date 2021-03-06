﻿Shader "Custom/GPUSnowFall"
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
            float  _DeformationRatio;

            sampler2D _MainTex;
            float4    _MainTex_ST;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 position   : SV_POSITION;
                float2 uv         : TEXCOORD0;
                half4  color      : TEXCOORD1;
                float  scale      : PSIZE;
                uint   vertexID   : TESSFACTOR0;
                float  depthLevel : TESSFACTOR1;
            };

            float GetRandomValue(float2 coord, int Seed)
            {
                return frac(sin(dot(coord.xy, float2(12.9898, 78.233)) + Seed) * 43758.5453);
            }

            // ------------------------------------------------------------------------------------
            // VertexShader
            // ------------------------------------------------------------------------------------

            vertexOutput vertexShader(uint vertexID : SV_VertexID)
            {
                vertexOutput output;

                // 少し暗い雪も用意する。
                half color = saturate(GetRandomValue(float2(0, 0), vertexID) + 0.8);

                output.position   = float4(_VertexBuffer[vertexID] + _OriginPosition, 1);
                output.uv         = float2(0, 0);
                output.color      = half4(color, color, color, 1);
                output.scale      = _ScaleBuffer[vertexID];
                output.vertexID   = vertexID;
                output.depthLevel = 0;

                return output;
            }

            // ------------------------------------------------------------------------------------
            // GeometryShader
            // ------------------------------------------------------------------------------------

            [maxvertexcount(4)]
            void geometryShader(point vertexOutput input[1],
                inout TriangleStream<vertexOutput> outputStream)
            {
                // ビルボード処理とメッシュの登録

                // UNITY_MATRIX_IT_MV[1].xyz  はカメラの上ベクトルを取得できます。
                // UNITY_MATRIX_V[0].xyz * -1 はカメラの右ベクトルを取得することができます。
                // SceneView でもビルボードの方向を正しく取得するためにこのように実装しています。
                // 
                // 一般的な取得方法は概ね次のようになります。
                // ObjSpaceViewDir はオブジェクトからカメラへのベクトルです。
                // float3 cameraUp    = normalize(_CameraUp);
                // float3 eyeVector   = normalize(ObjSpaceViewDir(position.xyz));
                // float3 cameraRight = normalize(cross(eyeVector, cameraUp));

                float3   cameraUp    = UNITY_MATRIX_IT_MV[1].xyz;
                float3   cameraRight = UNITY_MATRIX_V[0].xyz * -1;
                float4x4 projection  = mul(UNITY_MATRIX_MVP, unity_WorldToObject);
                float4 basePosition  = input[0].position;

                // Unity は左て座標系なので時計回りに頂点を定義すると、視線方向から見て表向きのメッシュになります。
                // ここでの視線の方向は、オブジェクトから向かってカメラへのベクトルで定義されます。
                // したがって反時計回りに頂点を定義すると、カメラから見て表向きのメッシュが定義されます。
                // 右下、右上、左下、左上の順で定義します。

                //vertexOutput output;

                //output.color    = input[0].color;
                //output.scale    = input[0].scale;
                //output.vertexID = input[0].vertexID;

                //for (int x = 1; x > -1; x--)
                //{
                //    for (int y = 0; y < 2; y++)
                //    {
                //        output.position = float4(basePosition + output.scale * x * cameraRight
                //                                              + output.scale * y * cameraUp, 1);
                //        output.position = mul(projection, output.position);
                //        output.uv       = TRANSFORM_TEX(float2(x, y), _MainTex);

                //        outputStream.Append(output);
                //    }
                //}

                //outputStream.RestartStrip();

                // 新規実装

                vertexOutput output;
                
                output.color      = input[0].color;
                output.scale      = input[0].scale;
                output.vertexID   = input[0].vertexID;
                output.depthLevel = saturate(length(basePosition - _WorldSpaceCameraPos) * 0.1);  // means / 10

                float  halfLength       = output.scale * 0.5;
                float  fluctuation      = 0;
                float  DeformationRatio = _DeformationRatio;

                float2 rightBottom = float2(1, 0);
                float2 rightTop    = float2(1, 1);
                float2 leftBottom  = float2(0, 0);
                float2 leftTop     = float2(0, 1);

                // RightBottom

                fluctuation        = GetRandomValue(rightBottom, output.vertexID) * output.scale * DeformationRatio;
                output.position    = float4(basePosition + (halfLength + fluctuation) * cameraRight
                                                         - (halfLength + fluctuation) * cameraUp, 1);
                output.position    = mul(projection, output.position);
                output.uv          = TRANSFORM_TEX(rightBottom, _MainTex);

                outputStream.Append(output);

                // RightTop

                fluctuation     = GetRandomValue(rightTop, output.vertexID) * output.scale * DeformationRatio;
                output.position = float4(basePosition + (halfLength + fluctuation) * cameraRight
                                                      + (halfLength + fluctuation) * cameraUp, 1);
                output.position = mul(projection, output.position);
                output.uv       = TRANSFORM_TEX(rightTop, _MainTex);

                outputStream.Append(output);

                // LeftBottom

                fluctuation     = GetRandomValue(leftBottom, output.vertexID) * output.scale * DeformationRatio;
                output.position = float4(basePosition - (halfLength + fluctuation) * cameraRight
                                                      - (halfLength + fluctuation) * cameraUp, 1);
                output.position = mul(projection, output.position);
                output.uv       = TRANSFORM_TEX(leftBottom, _MainTex);

                outputStream.Append(output);

                // LeftTop

                fluctuation     = GetRandomValue(leftTop, output.vertexID) * output.scale * DeformationRatio;
                output.position = float4(basePosition - (halfLength + fluctuation) * cameraRight
                                                      + (halfLength + fluctuation) * cameraUp, 1);
                output.position = mul(projection, output.position);
                output.uv       = TRANSFORM_TEX(leftTop, _MainTex);

                outputStream.Append(output);

                outputStream.RestartStrip();
            }

            // ------------------------------------------------------------------------------------
            // FragmentShader
            // ------------------------------------------------------------------------------------

            fixed4 fragmentShader(vertexOutput input) : COLOR
            {
                float mipLevel = 4 - input.depthLevel * 4;

                //if (mipLevel < 1)
                //{
                //    return fixed4(1, 0, 0, 1);
                //}
                //if (mipLevel < 2)
                //{
                //    return fixed4(0, 1, 0, 1);
                //}
                //if (mipLevel < 3)
                //{
                //    return fixed4(0, 0, 1, 1);
                //}
                //if (mipLevel < 4)
                //{
                //    return fixed4(1, 1, 0, 1);
                //}
                //if (mipLevel >= 4)
                //{
                //    return fixed4(0, 0, 0, 1);
                //}

                fixed4 color;

                color    = tex2Dlod(_MainTex, float4(input.uv, 0, 4 - input.depthLevel * 4));
                color.a *= input.depthLevel;

                // 一般的な色の設定

                //color = tex2D(_MainTex, input.uv);

                // メッシュの変形などを確認するとき単色で出す。

                //color = float4(1, 1, 0, 1);

                // 描画オブジェクトの前後関係が重要なときは、
                // ZWrite を有効にして透過部分は α で削る。

                //if (color.a < 0.01)
                //{
                //    discard;
                //}

                return color;
            }

            ENDCG
        }
    }
}