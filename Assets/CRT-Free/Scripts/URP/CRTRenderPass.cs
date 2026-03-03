// CRTRenderPass.cs
// The actual render pass that blits the CRT effect in URP.

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BrewedInk.CRT.URP
{
    public class CRTRenderPass : ScriptableRenderPass, IDisposable
    {
        private const string ProfilerTag = "CRT Effect";

        // Shader property IDs (mirrors CRTCameraBehaviour)
        private static readonly int PropMaxColorsRed          = Shader.PropertyToID("_MaxColorsRed");
        private static readonly int PropMaxColorsGreen        = Shader.PropertyToID("_MaxColorsGreen");
        private static readonly int PropMaxColorsBlue         = Shader.PropertyToID("_MaxColorsBlue");
        private static readonly int PropDitheringAmount       = Shader.PropertyToID("_Spread");
        private static readonly int PropDitheringAmount8      = Shader.PropertyToID("_Spread8");
        private static readonly int PropVignette              = Shader.PropertyToID("_VigSize");
        private static readonly int PropMonitorRoundness      = Shader.PropertyToID("_BorderOutterRound");
        private static readonly int PropMonitorTexture        = Shader.PropertyToID("_BorderTex");
        private static readonly int PropMonitorColor          = Shader.PropertyToID("_BorderTint");
        private static readonly int PropInnerDarkness         = Shader.PropertyToID("_BorderInnerDarkerAmount");
        private static readonly int PropInnerGlow             = Shader.PropertyToID("_CrtGlowAmount");
        private static readonly int PropInnerReflectionRadius = Shader.PropertyToID("_CrtReflectionRadius");
        private static readonly int PropInnerReflectionCurve  = Shader.PropertyToID("_CrtReflectionCurve");
        private static readonly int PropMonitorCurve          = Shader.PropertyToID("_Curvature2");
        private static readonly int PropInnerCurve            = Shader.PropertyToID("_Curvature");
        private static readonly int PropZoom                  = Shader.PropertyToID("_BorderZoom");
        private static readonly int PropInnerSizeX            = Shader.PropertyToID("_BorderInnerSizeX");
        private static readonly int PropInnerSizeY            = Shader.PropertyToID("_BorderInnerSizeY");
        private static readonly int PropOutterSizeX           = Shader.PropertyToID("_BorderOutterSizeX");
        private static readonly int PropOutterSizeY           = Shader.PropertyToID("_BorderOutterSizeY");
        private static readonly int PropColorScans            = Shader.PropertyToID("_ColorScans");
        private static readonly int PropDesaturation          = Shader.PropertyToID("_Desaturation");
        private static readonly int PropBrewedInkBayer4       = Shader.PropertyToID("_BrewedInk_Bayer4");
        private static readonly int PropBrewedInkBayer8       = Shader.PropertyToID("_BrewedInk_Bayer8");

        private static readonly float[] Bayer4 =
        {
             0, 8, 2,10,
            12, 4,14, 6,
             3,11, 1, 9,
            15, 7,13, 5
        };

        private static readonly float[] Bayer8 =
        {
             0,32, 8,40, 2,34,10,42,
            48,16,56,24,50,18,58,26,
            12,44, 4,36,14,46, 6,38,
            60,28,52,20,62,30,54,22,
             3,35,11,43, 1,33, 9,41,
            51,19,59,27,49,17,57,25,
            15,47, 7,39,13,45, 5,37,
            63,31,55,23,61,29,53,21
        };

        private readonly string _profilerTag;
        private CRTCameraURPBehaviour _behaviour;

        // RTHandles for the temporary blit texture
        private RTHandle _tempColorHandle;
        private RTHandle _tempPixelHandle; // used when pixelation > 1

        public CRTRenderPass(string profilerTag)
        {
            _profilerTag = profilerTag;
        }

        public void Setup(CRTCameraURPBehaviour behaviour)
        {
            _behaviour = behaviour;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref _tempColorHandle, desc, FilterMode.Bilinear, name: "_CRTTempColor");
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_behaviour == null || _behaviour.data == null || _behaviour.RuntimeMaterial == null)
                return;

            var mat = _behaviour.RuntimeMaterial;
            var data = _behaviour.data;

            // Upload shader properties
            Shader.SetGlobalFloatArray(PropBrewedInkBayer4, Bayer4);
            Shader.SetGlobalFloatArray(PropBrewedInkBayer8, Bayer8);
            mat.SetFloat(PropMaxColorsRed,          data.maxColorChannels.red);
            mat.SetFloat(PropMaxColorsGreen,        data.maxColorChannels.green);
            mat.SetFloat(PropMaxColorsBlue,         data.maxColorChannels.blue);
            mat.SetFloat(PropDitheringAmount,       data.dithering4);
            mat.SetFloat(PropDitheringAmount8,      data.dithering8);
            mat.SetFloat(PropVignette,              data.vignette);
            mat.SetFloat(PropMonitorRoundness,      data.monitorRoundness);
            mat.SetFloat(PropInnerDarkness,         1 - data.innerMonitorDarkness);
            mat.SetFloat(PropInnerGlow,             data.innerMonitorShine);
            mat.SetFloat(PropInnerReflectionRadius, data.innerMonitorShineRadius);
            mat.SetFloat(PropInnerReflectionCurve,  data.innerMonitorShineCurve);
            mat.SetFloat(PropMonitorCurve,          data.monitorCurve);
            mat.SetFloat(PropInnerCurve,            data.innerCurve);
            mat.SetFloat(PropZoom,                  data.zoom);
            mat.SetFloat(PropInnerSizeX,            data.monitorInnerSize.width);
            mat.SetFloat(PropInnerSizeY,            data.monitorInnerSize.height);
            mat.SetFloat(PropDesaturation,          data.maxColorChannels.greyScale);
            mat.SetFloat(PropOutterSizeX,           data.monitorOutterSize.width);
            mat.SetFloat(PropOutterSizeY,           data.monitorOutterSize.height);
            mat.SetVector(PropColorScans, new Vector4(
                data.colorScans.greenChannelMultiplier,
                data.colorScans.redBlueChannelMultiplier,
                data.colorScans.sizeMultiplier,
                0));
            mat.SetTexture(PropMonitorTexture, data.monitorTexture);
            mat.SetColor(PropMonitorColor,    data.monitorColor);

            var cmd = CommandBufferPool.Get(_profilerTag);

            var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

            if (data.pixelationAmount > 1)
            {
                var downSample = Mathf.Min(300, data.pixelationAmount);
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                desc.width  = Mathf.Max(1, desc.width  / downSample);
                desc.height = Mathf.Max(1, desc.height / downSample);
                RenderingUtils.ReAllocateIfNeeded(ref _tempPixelHandle, desc, FilterMode.Point, name: "_CRTPixelTemp");

                // Downsample -> CRT blit -> back to camera target
                Blit(cmd, cameraTarget, _tempPixelHandle);
                Blit(cmd, _tempPixelHandle, _tempColorHandle, mat);
                Blit(cmd, _tempColorHandle, cameraTarget);
            }
            else
            {
                // Straight CRT blit
                Blit(cmd, cameraTarget, _tempColorHandle, mat);
                Blit(cmd, _tempColorHandle, cameraTarget);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) { }

        public void Dispose()
        {
            _tempColorHandle?.Release();
            _tempPixelHandle?.Release();
        }
    }
}
