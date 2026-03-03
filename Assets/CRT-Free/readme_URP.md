# CRT-Free — URP Support

This folder adds Universal Render Pipeline (URP) support to the original CRT-Free asset, compatible with **Unity 6** and **URP 14+**.

## New Files

| File | Purpose |
|---|---|
| `Materials/CRTUnlit_URP.shader` | HLSL port of the original CG shader, URP-compatible |
| `Scripts/URP/CRTRendererFeature.cs` | Plugs the CRT effect into the URP renderer pipeline |
| `Scripts/URP/CRTRenderPass.cs` | The actual blit pass (mirrors `OnRenderImage` logic) |
| `Scripts/URP/CRTCameraURPBehaviour.cs` | Camera component (replaces `CRTCameraBehaviour`) |

---

## Setup Steps

### 1 — Create a URP material
1. In the **Project** window, right-click → **Create → Material**.
2. Set the shader to **BrewedInk/CRTUnlit_URP**.
3. Assign your noise texture to **BorderTexture** if desired.

### 2 — Create a CRTRenderSettings asset
1. Right-click → **Create → ScriptableObject → CRTRenderSettingsObject** (or use the existing one in `CRT-Free/`).
2. Drag your new URP material into the **Crt Material** slot.

### 3 — Add the Renderer Feature
1. Find your **Universal Renderer** asset (usually in `Settings/`).
2. In the Inspector, click **Add Renderer Feature → CRT Renderer Feature**.
3. Drag the `CRTRenderSettingsObject` into the **Crt Render Settings** slot on the feature.

### 4 — Add the camera component
1. Select your **Main Camera**.
2. **Remove** the old `CRTCameraBehaviour` (if present).
3. **Add Component → CRTCameraURPBehaviour**.
4. Assign your `CRTDataObject` preset (e.g. `Subtle`, `RetroBlue`, etc.) to **Start Config**.
5. Assign the same `CRTRenderSettingsObject` to **Crt Render Settings**.

> The `CRTCameraURPBehaviour` creates the runtime material and feeds data to the render pass — no `OnRenderImage` needed.

---

## Notes
- The **original** `CRTCameraBehaviour` still works unchanged in the **Built-in RP**.
- All `CRTDataObject` presets (Subtle, Gloss, Moon, RetroBlue, RetroRed, Grey) are fully compatible with both pipelines.
- `CRTDemoBehaviour` (the demo script) works with both behaviours — just swap the component reference if you use it.
- For **Scene View** preview, uncomment `[ImageEffectAllowedInSceneView]` on `CRTCameraURPBehaviour` (URP scene view support requires additional setup in newer Unity versions).
