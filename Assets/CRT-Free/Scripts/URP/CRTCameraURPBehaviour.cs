// CRTCameraURPBehaviour.cs
// URP replacement for CRTCameraBehaviour.
// Attach this component to your Camera instead of CRTCameraBehaviour when using URP.
// The actual rendering is done by CRTRendererFeature / CRTRenderPass.

using System;
using UnityEngine;

namespace BrewedInk.CRT.URP
{
    [RequireComponent(typeof(Camera))]
    [ExecuteAlways]
    public class CRTCameraURPBehaviour : MonoBehaviour
    {
        [Header("Configuration")]
        public CRTDataObject startConfig;
        public CRTRenderSettingsObject crtRenderSettings;

        [Header("Runtime Data (edit with care!)")]
        public Material _runtimeMaterial;
        public CRTData data;

        /// <summary>Exposes the runtime material to the render pass.</summary>
        public Material RuntimeMaterial => _runtimeMaterial;

        private string _lastValidationId;

        [ContextMenu("Reset Material")]
        public void ResetMaterial()
        {
            DestroyMaterial();
            CreateMaterial();
        }

        private void OnDestroy() => DestroyMaterial();

        private void DestroyMaterial()
        {
            if (_runtimeMaterial != null)
            {
                DestroyImmediate(_runtimeMaterial);
                _runtimeMaterial = null;
            }
        }

        private void CreateMaterial()
        {
            if (crtRenderSettings != null && crtRenderSettings.crtMaterial != null && _runtimeMaterial == null)
                _runtimeMaterial = new Material(crtRenderSettings.crtMaterial);

            if (startConfig != null && !string.Equals(_lastValidationId, startConfig.validationId))
            {
                _lastValidationId = startConfig.validationId;
                data = startConfig.data.Clone();
            }
        }

        private void Update() => CreateMaterial();
    }
}
