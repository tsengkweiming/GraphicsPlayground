using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace GraphicsPlayground.CustomPostProcessing
{
    public sealed class TemporalDiffusionRendererFeature : ScriptableRendererFeature
    {
        private const string ShaderName = "Hidden/GraphicsPlayground/TemporalDiffusion";

        [Serializable]
        public sealed class Settings
        {
            [Tooltip("Optional explicit shader reference. The feature uses Shader.Find as an editor fallback.")]
            public Shader shader;

            [Tooltip("The effect normally runs before URP color grading and bloom.")]
            public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

            [Tooltip("Preview the effect in the Scene view as well as Game cameras.")]
            public bool applyToSceneView = true;

            [Tooltip("Reset feedback when the camera teleports farther than this distance in one frame. Set to zero to disable position checks.")]
            [Min(0.0f)] public float cameraCutDistance = 5.0f;

            [Tooltip("Reset feedback when the camera rotates farther than this angle in one frame. Set to zero to disable rotation checks.")]
            [Range(0.0f, 180.0f)] public float cameraCutAngle = 50.0f;
        }

        private readonly struct EffectParameters
        {
            public readonly Vector4 feedback;
            public readonly Vector4 diffusion;
            public readonly Vector4 chromatic;
            public readonly Vector4 flow;

            public EffectParameters(
                TemporalDiffusion volume,
                in RenderTextureDescriptor descriptor,
                bool historyValid)
            {
                Vector2 direction = volume.chromaticDirection.value;
                float directionLengthSq = direction.sqrMagnitude;
                direction = directionLengthSq > 1e-6f ? direction / Mathf.Sqrt(directionLengthSq) : Vector2.right;

                feedback = new Vector4(
                    volume.intensity.value,
                    volume.feedback.value,
                    volume.historyDecay.value,
                    volume.motionResponse.value);

                diffusion = new Vector4(
                    volume.diffusionRadius.value,
                    volume.diffusionRate.value,
                    1.0f / Mathf.Max(descriptor.width, 1),
                    1.0f / Mathf.Max(descriptor.height, 1));

                chromatic = new Vector4(
                    direction.x,
                    direction.y,
                    volume.chromaticSeparation.value,
                    0.0f);

                flow = new Vector4(
                    volume.flowStrength.value,
                    volume.flowScale.value,
                    volume.flowSpeed.value,
                    historyValid ? 1.0f : 0.0f);
            }
        }

        private sealed class CameraHistory : IDisposable
        {
            private readonly RTHandle[] m_Buffers = new RTHandle[2];
            private int m_ReadIndex;

            public bool valid { get; private set; }
            public int lastFrame { get; private set; } = -1;
            public Vector3 lastPosition { get; private set; }
            public Quaternion lastRotation { get; private set; }
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

                bool discontinuousFrame = lastFrame >= 0 && frame - lastFrame > 1;
                bool positionCut = valid && cutDistance > 0.0f &&
                                   (cameraTransform.position - lastPosition).sqrMagnitude > cutDistance * cutDistance;
                bool rotationCut = valid && cutAngle > 0.0f &&
                                   Quaternion.Angle(cameraTransform.rotation, lastRotation) > cutAngle;

                if (reallocated || discontinuousFrame || positionCut || rotationCut)
                    valid = false;

                lastFrame = frame;
                lastPosition = cameraTransform.position;
                lastRotation = cameraTransform.rotation;
            }

            public void Invalidate()
            {
                valid = false;
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

        private sealed class TemporalDiffusionPass : ScriptableRenderPass
        {
            private static readonly int HistoryTextureId = Shader.PropertyToID("_HistoryTexture");
            private static readonly int FeedbackId = Shader.PropertyToID("_TD_Feedback");
            private static readonly int DiffusionId = Shader.PropertyToID("_TD_Diffusion");
            private static readonly int ChromaticId = Shader.PropertyToID("_TD_Chromatic");
            private static readonly int FlowId = Shader.PropertyToID("_TD_Flow");
            private static readonly Vector4 ScaleBias = new(1.0f, 1.0f, 0.0f, 0.0f);

            private sealed class PassData
            {
                public TextureHandle source;
                public TextureHandle history;
                public Material material;
                public EffectParameters parameters;
            }

            private Material m_Material;
            private CameraHistory m_History;
            private EffectParameters m_Parameters;

            public TemporalDiffusionPass()
            {
                profilingSampler = new ProfilingSampler("Temporal Diffusion");
                requiresIntermediateTexture = true;
            }

            public void Setup(Material material, CameraHistory history, EffectParameters parameters)
            {
                m_Material = material;
                m_History = history;
                m_Parameters = parameters;
            }

            private static void SetParameters(
                RasterCommandBuffer commandBuffer,
                TextureHandle history,
                in EffectParameters parameters)
            {
                commandBuffer.SetGlobalTexture(HistoryTextureId, history);
                commandBuffer.SetGlobalVector(FeedbackId, parameters.feedback);
                commandBuffer.SetGlobalVector(DiffusionId, parameters.diffusion);
                commandBuffer.SetGlobalVector(ChromaticId, parameters.chromatic);
                commandBuffer.SetGlobalVector(FlowId, parameters.flow);
            }

            private static void ExecutePass(PassData data, RasterGraphContext context)
            {
                SetParameters(context.cmd, data.history, data.parameters);
                Blitter.BlitTexture(context.cmd, data.source, ScaleBias, data.material, 0);
            }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
                if (resourceData.isActiveTargetBackBuffer || m_Material == null || m_History?.write == null)
                    return;

                TextureHandle source = resourceData.activeColorTexture;
                TextureHandle destination = renderGraph.ImportTexture(m_History.write);
                TextureHandle history = m_History.valid
                    ? renderGraph.ImportTexture(m_History.read)
                    : source;

                if (!source.IsValid() || !destination.IsValid() || !history.IsValid())
                    return;

                using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                           "Temporal Diffusion Accumulation", out PassData passData, profilingSampler))
                {
                    passData.source = source;
                    passData.history = history;
                    passData.material = m_Material;
                    passData.parameters = m_Parameters;

                    builder.UseTexture(source, AccessFlags.Read);
                    builder.UseTexture(history, AccessFlags.Read);
                    builder.SetRenderAttachment(destination, 0, AccessFlags.Write);
                    builder.AllowGlobalStateModification(true);
                    builder.SetRenderFunc(static (PassData data, RasterGraphContext context) => ExecutePass(data, context));
                }

                resourceData.cameraColor = destination;
                m_History.Commit();
            }

#pragma warning disable 618, 672
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (m_Material == null || m_History?.write == null)
                    return;

                RTHandle source = renderingData.cameraData.renderer.cameraColorTargetHandle;
                RTHandle history = m_History.valid ? m_History.read : source;
                CommandBuffer commandBuffer = CommandBufferPool.Get("Temporal Diffusion");

                commandBuffer.SetGlobalTexture(HistoryTextureId, history);
                commandBuffer.SetGlobalVector(FeedbackId, m_Parameters.feedback);
                commandBuffer.SetGlobalVector(DiffusionId, m_Parameters.diffusion);
                commandBuffer.SetGlobalVector(ChromaticId, m_Parameters.chromatic);
                commandBuffer.SetGlobalVector(FlowId, m_Parameters.flow);
                Blitter.BlitCameraTexture(commandBuffer, source, m_History.write, m_Material, 0);
                Blitter.BlitCameraTexture(commandBuffer, m_History.write, source);

                context.ExecuteCommandBuffer(commandBuffer);
                CommandBufferPool.Release(commandBuffer);
                m_History.Commit();
            }
#pragma warning restore 618, 672
        }

        [SerializeField] private Settings settings = new();

        private readonly Dictionary<int, CameraHistory> m_CameraHistories = new();
        private TemporalDiffusionPass m_Pass;
        private Material m_Material;

        public override void Create()
        {
            m_Pass ??= new TemporalDiffusionPass();
            m_Pass.renderPassEvent = settings.injectionPoint;
            EnsureMaterial();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            CameraData cameraData = renderingData.cameraData;
            Camera camera = cameraData.camera;
            int cameraId = camera.GetInstanceID();

            if (!m_CameraHistories.TryGetValue(cameraId, out CameraHistory history))
            {
                history = new CameraHistory();
                m_CameraHistories.Add(cameraId, history);
            }

            TemporalDiffusion volume = VolumeManager.instance.stack.GetComponent<TemporalDiffusion>();
            bool supportedCamera = cameraData.renderType == CameraRenderType.Base &&
                                   (camera.cameraType == CameraType.Game ||
                                    (settings.applyToSceneView && camera.cameraType == CameraType.SceneView));

            if (!supportedCamera || !cameraData.postProcessEnabled || volume == null || !volume.IsActive())
            {
                history.Invalidate();
                return;
            }

            if (!EnsureMaterial())
                return;

            RenderTextureDescriptor descriptor = cameraData.cameraTargetDescriptor;
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
                settings.cameraCutDistance,
                settings.cameraCutAngle);

            m_Pass.renderPassEvent = settings.injectionPoint;
            m_Pass.Setup(m_Material, history, new EffectParameters(volume, descriptor, history.valid));
            renderer.EnqueuePass(m_Pass);
        }

        private bool EnsureMaterial()
        {
            Shader shader = settings.shader != null ? settings.shader : Shader.Find(ShaderName);
            if (shader == null)
                return false;

            if (m_Material != null && m_Material.shader == shader)
                return true;

            CoreUtils.Destroy(m_Material);
            m_Material = CoreUtils.CreateEngineMaterial(shader);
            return m_Material != null;
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(m_Material);
            m_Material = null;

            foreach (CameraHistory history in m_CameraHistories.Values)
                history.Dispose();

            m_CameraHistories.Clear();
        }
    }
}
