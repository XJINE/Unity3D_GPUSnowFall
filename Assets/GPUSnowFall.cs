using System.Runtime.InteropServices;
using UnityEngine;

public class GPUSnowFall : MonoBehaviour
{
    #region Field

    /// <summary>
    /// 雪を生成して描画するシェーダ。
    /// </summary>
    public Shader gpuSnowFallShader;

    /// <summary>
    /// 雪を動かすコンピュートシェーダ。
    /// </summary>
    public ComputeShader gpuSnowFallComputeShader;

    /// <summary>
    /// 雪のパーティクルの数。
    /// </summary>
    [Range(0, 1000000)]
    public int particleCount = 1000;

    /// <summary>
    /// 雪を降らせる最小の位置。
    /// </summary>
    public Vector3 minRange;

    /// <summary>
    /// 雪を降らせる最大の位置。
    /// </summary>
    public Vector3 maxRange;

    /// <summary>
    /// 雪の最小のサイズ。
    /// </summary>
    public float minScale;

    /// <summary>
    /// 雪の最大のサイズ。
    /// </summary>
    public float maxScale;

    /// <summary>
    /// 雪の流れる方向(風向き)。
    /// </summary>
    public Vector3 wind = new Vector3(0, -0.1f, 0);

    /// <summary>
    /// 雪の揺らぎの速度。
    /// </summary>
    public float 
fluctuationSpeed = 0.2f;

    /// <summary>
    /// 雪の揺らぎの幅。
    /// </summary>
    public float fluctuationScale = 0.05f;

    /// <summary>
    /// 大きさによって影響を受ける方向。
    /// 小さいほど受ける影響は小さくなります。
    /// </summary>
    public Vector3 scaleInfluence = new Vector3(0, -0.2f, 0);

    /// <summary>
    /// 変形の程度。
    /// </summary>
    public float deformationRatio = 0.7f;

    /// <summary>
    /// 雪の描画を実行するマテリアル。
    /// </summary>
    private Material material;

    /// <summary>
    /// 雪の座標情報を持つ GPU 上のバッファ。
    /// </summary>
    private ComputeBuffer vertexBuffer;

    /// <summary>
    /// 雪のサイズ情報を持つ GPU 上のバッファ。
    /// </summary>
    private ComputeBuffer scaleBuffer;

    /// <summary>
    /// 雪を動かすカーネル(関数)の名前。
    /// </summary>
    private static readonly string kernelNameSnowFall = "SnowFall";

    /// <summary>
    /// 雪を動かすカーネル(関数)のインデックス。
    /// </summary>
    private int kernelIndexSnowFall;

    /// <summary>
    /// 雪を動かすカーネル(関数)の実行スレッド数。
    /// </summary>
    private Vector3 kernelThreadGroupSizeSnowFall;

    #endregion Field

    #region Method

    /// <summary>
    /// 開始時に呼び出されます。
    /// </summary>
    protected virtual void Start()
    {
        // (1) ランダムな位置に雪の座標を生成して VertexBuffer に登録します。

        Vector3[] vertices = GenerateRandomPositionVertexes
            (this.particleCount, this.minRange, this.maxRange);

        this.vertexBuffer = new ComputeBuffer(this.particleCount, Marshal.SizeOf(typeof(Vector3)));
        this.vertexBuffer.SetData(vertices);

        this.scaleBuffer = new ComputeBuffer(this.particleCount, Marshal.SizeOf(typeof(float)));
        this.scaleBuffer.SetData(GenerateRandomValues(this.particleCount, this.minScale, this.maxScale));

        // VertexBuffer の登録。

        this.material = new Material(this.gpuSnowFallShader);
        this.material.SetBuffer("_VertexBuffer",  this.vertexBuffer);
        this.material.SetBuffer("_ScaleBuffer",   this.scaleBuffer);

        // ComputeShader の初期化と VertexBuffer の登録。

        this.kernelIndexSnowFall = this.gpuSnowFallComputeShader.FindKernel(GPUSnowFall.kernelNameSnowFall);

        uint sizeX, sizeY, sizeZ;
        this.gpuSnowFallComputeShader.GetKernelThreadGroupSizes(this.kernelIndexSnowFall, out sizeX, out sizeY, out sizeZ);
        this.kernelThreadGroupSizeSnowFall = new Vector3(sizeX, sizeY, sizeZ);

        this.gpuSnowFallComputeShader.SetBuffer(this.kernelIndexSnowFall, "_VertexBuffer", this.vertexBuffer);
        this.gpuSnowFallComputeShader.SetBuffer(this.kernelIndexSnowFall, "_ScaleBuffer",  this.scaleBuffer);
    }

    /// <summary>
    /// 更新時に呼び出されます。
    /// </summary>
    protected virtual void LateUpdate()
    {
        // 雪の頂点を動かします。
        this.gpuSnowFallComputeShader.Dispatch(this.kernelIndexSnowFall,
                                               (int)(this.particleCount / this.kernelThreadGroupSizeSnowFall.x),
                                               1,
                                               1);

        this.gpuSnowFallComputeShader.SetVector("_MinRange",     this.minRange);
        this.gpuSnowFallComputeShader.SetVector("_MaxRange",     this.maxRange);
        this.gpuSnowFallComputeShader.SetVector("_MovePower",    this.wind);

        this.gpuSnowFallComputeShader.SetFloat("_MinScale",        this.minScale);
        this.gpuSnowFallComputeShader.SetFloat("_MaxScale",        this.maxScale);
        this.gpuSnowFallComputeShader.SetVector("_ScaleInfluence", this.scaleInfluence);

        this.gpuSnowFallComputeShader.SetFloat("_Time",          Time.time);
        this.gpuSnowFallComputeShader.SetFloat("_FluctuationSpeed", this.fluctuationSpeed);
        this.gpuSnowFallComputeShader.SetFloat("_FluctuationScale", this.fluctuationScale);

        this.material.SetVector("_OriginPosition",  base.transform.position);
        this.material.SetFloat("_DeformationRatio", this.deformationRatio);
    }

    /// <summary>
    /// 描画時に呼び出されます。
    /// </summary>
    protected virtual void OnRenderObject()
    {
        this.material.SetPass(0);
        Graphics.DrawProcedural(MeshTopology.Points, this.particleCount);
    }

    /// <summary>
    /// 破棄時に呼び出されます。
    /// </summary>
    protected virtual void OnDestroy()
    {
        // このインスタンスで生成したマテリアルを破棄します。
        // マテリアルは破棄しない限りリソースを消費し続けます。
        // ComputeBuffer も同様の理由で破棄します。

        DestroyImmediate(this.material);
        this.vertexBuffer.Release();
        this.scaleBuffer.Release();
    }

    /// <summary>
    /// 指定した数だけランダムに配置された頂点を生成します。
    /// </summary>
    /// <param name="count">
    /// 生成する頂点の数。
    /// </param>
    /// <param name="minRange">
    /// 生成する頂点の最小の範囲。
    /// </param>
    /// <param name="maxRange">
    /// 生成する頂点の最大の範囲。
    /// </param>
    /// <returns>
    /// ランダムに生成された頂点の配列。
    /// </returns>
    protected virtual Vector3[] GenerateRandomPositionVertexes
        (int count, Vector3 minRange, Vector3 maxRange)
    {
        Vector3[] array = new Vector3[count];

        for (int i = 0; i < count; i++)
        {
            array[i] = new Vector3(Random.Range(minRange.x, maxRange.x),
                                   Random.Range(minRange.y, maxRange.y),
                                   Random.Range(minRange.z, maxRange.z));
        }

        return array;
    }

    /// <summary>
    /// 指定した数だけランダムな値を生成します。
    /// </summary>
    /// <param name="count">
    /// 生成する値の数。
    /// </param>
    /// <param name="minRange">
    /// 生成する値の最小の範囲。
    /// </param>
    /// <param name="maxRange">
    /// 生成する値の最大の範囲。
    /// </param>
    /// <returns>
    /// ランダムに生成された値の配列。
    /// </returns>
    protected virtual float[] GenerateRandomValues
        (int count, float minRange, float maxRange)
    {
        float[] array = new float[count];

        for (int i = 0; i < count; i++)
        {
            array[i] = Random.Range(minRange, maxRange);
        }

        return array;
    }

    #endregion Method
}