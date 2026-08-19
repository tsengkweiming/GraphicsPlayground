using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [VolumeComponentMenu("Custom Post-processing/OctreeGridEffect")]
    public class OctreeGridEffect : CustomPostProcessing
    {
        private const int MaxOctreeLevels = 8;
        private const string ShaderName = "Hidden/CustomPostProcess/OctreeGridEffect";

        private static readonly int FactorId = Shader.PropertyToID("_T");
        private static readonly int SizeId = Shader.PropertyToID("_Size");
        private static readonly int ZId = Shader.PropertyToID("_Z");
        private static readonly int CellCountId = Shader.PropertyToID("_CellCount");
        private static readonly int CellSizeId = Shader.PropertyToID("_CellSize");
        private static readonly int Z2Id = Shader.PropertyToID("_Z2");
        private static readonly int BorderColorId = Shader.PropertyToID("_BorderColor");
        private static readonly int BorderRateId = Shader.PropertyToID("_BorderRate");
        private static readonly int StopThresholdId = Shader.PropertyToID("_SubdivisionStopThreshold");

        public ClampedFloatParameter factor = new (0f, 0f, 1f);
        public FloatParameter size = new (1.0f);
        public FloatParameter zFactor = new (0.2f);
        public ClampedIntParameter cellCount = new (3, 1, MaxOctreeLevels);
        public Vector3Parameter cellSize = new (Vector3.one * 0.5f);
        public ClampedFloatParameter subdivisionStopThreshold = new (0.5f, 0f, 1f);
        public ClampedFloatParameter zFactor2 = new (-0.04f, -0.3f, -0.03f);
        public ColorParameter borderColor = new (Color.white);
        public ClampedFloatParameter borderShowRate = new (0.2f, 0f, 1f);

        public override bool IsActive() => mMaterial != null && factor.value > 0.0f;
        public override CustomPostProcessEvent evt => CustomPostProcessEvent.AfterPostProcess;
        public override int OrderInEvent => 100;
        
        public override void Setup()
        {
            if (mMaterial == null)
                mMaterial = CoreUtils.CreateEngineMaterial(ShaderName);
        }

        public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
        {
            if (mMaterial == null) return;
            mMaterial.SetFloat(FactorId, factor.value);
            mMaterial.SetFloat(SizeId, size.value);
            mMaterial.SetFloat(ZId, zFactor.value);
            mMaterial.SetInt(CellCountId, cellCount.value);
            mMaterial.SetVector(CellSizeId, cellSize.value);
            mMaterial.SetFloat(StopThresholdId, subdivisionStopThreshold.value);
            mMaterial.SetFloat(Z2Id, zFactor2.value);
            mMaterial.SetColor(BorderColorId, borderColor.value);
            mMaterial.SetFloat(BorderRateId, borderShowRate.value);
            Draw(cmd, source, destination, 0);
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }

}
