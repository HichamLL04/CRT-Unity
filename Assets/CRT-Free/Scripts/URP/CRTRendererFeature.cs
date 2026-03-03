// CRTRendererFeature.cs
// URP support for CRT-Free by BrewedInk
// Drop this RendererFeature into your URP Universal Renderer asset.

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BrewedInk.CRT.URP
{
    public class CRTRendererFeature : ScriptableRendererFeature
    {
        [Tooltip("The CRT Render Settings asset (holds the CRT material).")]
        public CRTRenderSettingsObject crtRenderSettings;

        private CRTRenderPass _pass;

        public override void Create()
        {
            _pass = new CRTRenderPass(name)
            {
                renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // Only inject into game camera (skip reflection probes, previews, etc.)
            if (renderingData.cameraData.cameraType != CameraType.Game &&
                renderingData.cameraData.cameraType != CameraType.SceneView)
                return;

            if (crtRenderSettings == null || crtRenderSettings.crtMaterial == null)
            {
                Debug.LogWarning("[CRT-URP] CRTRenderSettings or its material is not assigned on the Renderer Feature.");
                return;
            }

            // Find a CRTCameraBehaviour in the scene that matches this camera
            var cam = renderingData.cameraData.camera;
            var behaviour = cam.GetComponent<CRTCameraURPBehaviour>();
            if (behaviour == null || !behaviour.enabled) return;

            _pass.Setup(behaviour);
            renderer.EnqueuePass(_pass);
        }

        protected override void Dispose(bool disposing)
        {
            _pass?.Dispose();
        }
    }
}
