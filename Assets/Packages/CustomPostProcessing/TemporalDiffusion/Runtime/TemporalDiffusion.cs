using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP.EFFECTS
{
    [Serializable]
    [VolumeComponentMenu("Custom Post-processing/Temporal Diffusion")]
    [SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
    public sealed class TemporalDiffusion : CustomPostProcessing
    {
        private const string ShaderName = "Hidden/GraphicsPlayground/TemporalDiffusion";

        [Tooltip("Enables the temporal diffusion effect.")]
        public BoolParameter enableEffect = new(false);

        [Tooltip("Blends between the untouched camera image and the accumulated result.")]
        public ClampedFloatParameter intensity = new(0.9f, 0.0f, 1.0f);

        [Tooltip("Amount of the previous frame retained. Higher values create longer trails.")]
        public ClampedFloatParameter feedback = new(0.92f, 0.0f, 0.995f);

        [Tooltip("Per-frame history fade. Lower values erase trails faster.")]
        public ClampedFloatParameter historyDecay = new(0.995f, 0.85f, 1.0f);

        [Tooltip("Distance, in pixels, between samples used by the diffusion operator.")]
        public ClampedFloatParameter diffusionRadius = new(1.25f, 0.0f, 6.0f);

        [Tooltip("Stable heat-equation coefficient. Values are limited below 0.25 to prevent runaway feedback.")]
        public ClampedFloatParameter diffusionRate = new(0.18f, 0.0f, 0.249f);

        [Tooltip("RGB history sample separation in pixels.")]
        public ClampedFloatParameter chromaticSeparation = new(1.4f, 0.0f, 8.0f);

        [Tooltip("Screen-space direction used to separate red and blue history samples.")]
        public Vector2Parameter chromaticDirection = new(new Vector2(1.0f, 0.35f));

        [Tooltip("Strength, in pixels, of the slowly animated history advection.")]
        public ClampedFloatParameter flowStrength = new(0.45f, 0.0f, 4.0f);

        [Tooltip("Spatial frequency of the procedural flow field.")]
        public ClampedFloatParameter flowScale = new(3.0f, 0.25f, 12.0f);

        [Tooltip("Animation rate of the procedural flow field.")]
        public ClampedFloatParameter flowSpeed = new(0.2f, -2.0f, 2.0f);

        [Tooltip("Makes changing pixels hold slightly more history than still pixels.")]
        public ClampedFloatParameter motionResponse = new(3.0f, 0.0f, 12.0f);

        [Tooltip("Reset feedback after a camera translation larger than this distance in one frame. Zero disables the check.")]
        public MinFloatParameter cameraCutDistance = new(5.0f, 0.0f);

        [Tooltip("Reset feedback after a camera rotation larger than this angle in one frame. Zero disables the check.")]
        public ClampedFloatParameter cameraCutAngle = new(50.0f, 0.0f, 180.0f);

        public override CustomPostProcessEvent evt => CustomPostProcessEvent.BeforePostProcess;
        public override int OrderInEvent => 90;

        private static readonly int HistoryTextureId = Shader.PropertyToID("_HistoryTexture");
        private static readonly int FeedbackId = Shader.PropertyToID("_TD_Feedback");
        private static readonly int DiffusionId = Shader.PropertyToID("_TD_Diffusion");
        private static readonly int ChromaticId = Shader.PropertyToID("_TD_Chromatic");
        private static readonly int FlowId = Shader.PropertyToID("_TD_Flow");

        private readonly Dictionary<int, CameraHistory> m_CameraHistories = new();

        public override bool IsActive() => mMaterial != null && enableEffect.value && intensity.value > 0.0f;

        public override void Setup()
        {
            if (mMaterial == null)
                mMaterial = CoreUtils.CreateEngineMaterial(ShaderName);
        }

        public override void Render(
            CommandBuffer cmd,
            ref RenderingData renderingData,
            RTHandle source,
            RTHandle destination)
        {
            if (mMaterial == null)
                return;

            Camera camera = renderingData.cameraData.camera;
            int cameraId = camera.GetInstanceID();

            if (!m_CameraHistories.TryGetValue(cameraId, out CameraHistory history))
            {
                history = new CameraHistory();
                m_CameraHistories.Add(cameraId, history);
            }

            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.msaaSamples = 1;
            descriptor.bindMS = false;
            descriptor.depthBufferBits = 0;
            descriptor.depthStencilFormat = GraphicsFormat.None;
            descriptor.useMipMap = false;
            descriptor.autoGenerateMips = false;

            history.Prepare(
                descriptor,
                cameraId,
                Time.frameCount,
                camera.transform,
                cameraCutDistance.value,
                cameraCutAngle.value);

            Vector2 direction = chromaticDirection.value;
            float directionLengthSq = direction.sqrMagnitude;
            direction = directionLengthSq > 1e-6f
                ? direction / Mathf.Sqrt(directionLengthSq)
                : Vector2.right;

            cmd.SetGlobalTexture(HistoryTextureId, history.valid ? history.read : source);
            cmd.SetGlobalVector(FeedbackId, new Vector4(
                intensity.value,
                feedback.value,
                historyDecay.value,
                motionResponse.value));
            cmd.SetGlobalVector(DiffusionId, new Vector4(
                diffusionRadius.value,
                diffusionRate.value,
                1.0f / Mathf.Max(descriptor.width, 1),
                1.0f / Mathf.Max(descriptor.height, 1)));
            cmd.SetGlobalVector(ChromaticId, new Vector4(
                direction.x,
                direction.y,
                chromaticSeparation.value,
                0.0f));
            cmd.SetGlobalVector(FlowId, new Vector4(
                flowStrength.value,
                flowScale.value,
                flowSpeed.value,
                history.valid ? 1.0f : 0.0f));

            // The shared stack owns destination. Accumulate into persistent history first,
            // then copy that exact result into the stack's ping-pong destination.
            Draw(cmd, source, history.write, 0);
            Blitter.BlitCameraTexture(cmd, history.write, destination);
            history.Commit();
        }

        public override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
            mMaterial = null;

            foreach (CameraHistory history in m_CameraHistories.Values)
                history.Dispose();

            m_CameraHistories.Clear();
        }

        private sealed class CameraHistory : IDisposable
        {
            private readonly RTHandle[] m_Buffers = new RTHandle[2];
            private int m_ReadIndex;
            private int m_LastFrame = -1;
            private Vector3 m_LastPosition;
            private Quaternion m_LastRotation;

            public bool valid { get; private set; }
            public RTHandle read => m_Buffers[m_ReadIndex];
            public RTHandle write => m_Buffers[1 - m_ReadIndex];

            public void Prepare(
                in RenderTextureDescriptor descriptor,
                int cameraId,
                int frame,
                Transform cameraTransform,
                float cutDistance,
                float cutAngle)
            {
                bool reallocated = false;
                reallocated |= RenderingUtils.ReAllocateHandleIfNeeded(
                    ref m_Buffers[0], descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp,
                    name: $"_TemporalDiffusionHistoryA_{cameraId}");
                reallocated |= RenderingUtils.ReAllocateHandleIfNeeded(
                    ref m_Buffers[1], descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp,
                    name: $"_TemporalDiffusionHistoryB_{cameraId}");

                bool discontinuousFrame = m_LastFrame >= 0 && frame - m_LastFrame > 1;
                bool positionCut = valid && cutDistance > 0.0f &&
                                   (cameraTransform.position - m_LastPosition).sqrMagnitude > cutDistance * cutDistance;
                bool rotationCut = valid && cutAngle > 0.0f &&
                                   Quaternion.Angle(cameraTransform.rotation, m_LastRotation) > cutAngle;

                if (reallocated || discontinuousFrame || positionCut || rotationCut)
                    valid = false;

                m_LastFrame = frame;
                m_LastPosition = cameraTransform.position;
                m_LastRotation = cameraTransform.rotation;
            }

            public void Commit()
            {
                m_ReadIndex = 1 - m_ReadIndex;
                valid = true;
            }

            public void Dispose()
            {
                m_Buffers[0]?.Release();
                m_Buffers[1]?.Release();
                m_Buffers[0] = null;
                m_Buffers[1] = null;
            }
        }
    }
}
