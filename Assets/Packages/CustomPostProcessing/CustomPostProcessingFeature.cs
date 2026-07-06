using System.Collections.Generic;
using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomPostProcessingFeature : ScriptableRendererFeature
{
   private List<CustomPostProcessing> mCustomPostProcessings;
   private bool mInitialized;

   private CustomPostProcessingPass mAfterOpaqueAndSkyPass;
   private CustomPostProcessingPass mBeforePostProcessPass;
   private CustomPostProcessingPass mAfterPostProcessPass;
   public override void Create()
   {
      mInitialized = false;
      mCustomPostProcessings = null;
      mAfterOpaqueAndSkyPass = null;
      mBeforePostProcessPass = null;
      mAfterPostProcessPass = null;
   }

   private bool EnsureInitialized()
   {
      if (mInitialized) return true;

      var volumeManager = VolumeManager.instance;
      if (volumeManager == null || !volumeManager.isInitialized || volumeManager.stack == null)
         return false;

      var stack = volumeManager.stack;
      // Collect all CustomPostProcessing instances after VolumeManager is ready.
      mCustomPostProcessings = volumeManager.baseComponentTypes
         .Where(t => t.IsSubclassOf(typeof(CustomPostProcessing)))
         .Select(t => stack.GetComponent(t) as CustomPostProcessing)
         .Where(c => c != null)
         .ToList();

      var afterOpaqueAndSkyCPPs = mCustomPostProcessings.Where(c => c.evt == CustomPostProcessEvent.AfterOpaqueAndSky)
         .OrderBy(c => c.OrderInEvent).ToList();
      mAfterOpaqueAndSkyPass = new CustomPostProcessingPass("Custom PostProcess after Skybox", afterOpaqueAndSkyCPPs);
      mAfterOpaqueAndSkyPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
      
      var beforePostProcessCPPS = mCustomPostProcessings.Where(c => c.evt == CustomPostProcessEvent.BeforePostProcess)
         .OrderBy(c => c.OrderInEvent).ToList();
      mBeforePostProcessPass =
         new CustomPostProcessingPass("Custom PostProcess before PostProcess", beforePostProcessCPPS);
      mBeforePostProcessPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
      
      var afterPostProcessCPPs = mCustomPostProcessings.Where(c => c.evt == CustomPostProcessEvent.AfterPostProcess)
         .OrderBy(c => c.OrderInEvent).ToList();
      mAfterPostProcessPass =
         new CustomPostProcessingPass("Custom PostProcess after PostProcess", afterPostProcessCPPs);
      mAfterPostProcessPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;

      mInitialized = true;
      return true;
   }

   public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
   {
      if (!renderingData.cameraData.postProcessEnabled) return;
      if (!EnsureInitialized()) return;

      if (mAfterOpaqueAndSkyPass != null && mAfterOpaqueAndSkyPass.SetupCustomPostProcessing())
      {
         mAfterOpaqueAndSkyPass.ConfigureInput(ScriptableRenderPassInput.Color);
         renderer.EnqueuePass(mAfterOpaqueAndSkyPass);
      }

      if (mBeforePostProcessPass != null && mBeforePostProcessPass.SetupCustomPostProcessing())
      {
         mBeforePostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
         renderer.EnqueuePass(mBeforePostProcessPass);
      }

      if (mAfterPostProcessPass != null && mAfterPostProcessPass.SetupCustomPostProcessing())
      {
         mAfterPostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
         renderer.EnqueuePass(mAfterPostProcessPass);
      }
   }

   protected override void Dispose(bool disposing)
   {
      base.Dispose(disposing);
      if(disposing && mCustomPostProcessings!=null)
         foreach (var item in mCustomPostProcessings)
         {
            item?.Dispose();
         }
      mAfterOpaqueAndSkyPass?.Dispose();
      mBeforePostProcessPass?.Dispose();
      mAfterPostProcessPass?.Dispose();
      mInitialized = false;
      
   }
}
