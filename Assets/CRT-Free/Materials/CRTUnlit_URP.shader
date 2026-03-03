Shader "BrewedInk/CRTUnlit_URP"
{
    Properties
    {
        _MainTex            ("Texture",         2D)             = "white" {}
        _BorderTex          ("BorderTexture",   2D)             = "white" {}
        _BorderTint         ("BorderTint",      Color)          = (1,1,1,1)

        _MaxColorsRed       ("MaxRedColors",    Range(0, 256))  = 0
        _MaxColorsGreen     ("MaxGreenColors",  Range(0, 256))  = 0
        _MaxColorsBlue      ("MaxBlueColors",   Range(0, 256))  = 0

        _Curvature          ("Curvature",       Range(0, 20))   = .2
        _Curvature2         ("Curvature2",      Range(0, .2))   = .05
        _VigSize            ("VigSize",         Range(0, 1))    = .1
        _ColorScans         ("ColorScans",      Vector)         = (0, 0, 0, 0)

        _BorderZoom         ("BorderZoom",      Range(.5, 2.5)) = 1
        _Desaturation       ("Desaturation",    Range(0, 1))    = 0

        _BorderOutterSizeX  ("BorderOutterSizeX", Range(0,.5)) = .2
        _BorderOutterSizeY  ("BorderOutterSizeY", Range(0,.5)) = .2
        _BorderOutterRound  ("BorderOutterRound", Range(0,.2)) = .01

        _BorderInnerSizeX   ("BorderInnerSizeX",  Range(0,.5)) = .2
        _BorderInnerSizeY   ("BorderInnerSizeY",  Range(0,.5)) = .2
        _BorderInnerDarkerAmount ("BorderInnerDarkerAmmount", Range(0,1)) = .5

        _BorderInnerSharpness  ("BorderInnerSharpness",  Range(0,1)) = .2
        _BorderOutterSharpness ("BorderOutterSharpness", Range(0,1)) = .2

        _CrtReflectionCurve   ("CrtReflectionCurve",   Range(0,10))   = .1
        _CrtReflectionRadius  ("CrtReflectionRadius",  Range(-.1,.1)) = .05
        _CrtReflectionFalloff ("CrtReflectionFalloff", Range(0,1))    = 0
        _CrtGlowAmount        ("CrtGlowAmount",         Range(0,.2))  = .1

        _Spread             ("DitherSpread4",   Range(0,1)) = .5
        _Spread8            ("DitherSpread8",   Range(0,1)) = .5
        _DitherScreenScale  ("DitherScreenScale", Range(.5,2)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType"      = "Opaque"
            "RenderPipeline"  = "UniversalPipeline"
        }
        LOD 100
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "CRT_URP"

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag
            #pragma target 3.5

            // URP core includes (replaces UnityCG.cginc)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // ---------------------------------------------------------------------------
            // Textures & Samplers
            // ---------------------------------------------------------------------------
            TEXTURE2D(_BorderTex);
            SAMPLER(sampler_BorderTex);

            // _BlitTexture / sampler_LinearClamp are provided by Blit.hlsl (_MainTex alias)
            // We expose _MainTex as well so the material inspector still works.
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // ---------------------------------------------------------------------------
            // Uniforms
            // ---------------------------------------------------------------------------
            CBUFFER_START(UnityPerMaterial)
                float4 _BorderTex_ST;
                float4 _BorderTint;
                float4 _ColorScans;

                float _Curvature;
                float _Curvature2;
                float _VigSize;
                float _BorderZoom;
                float _Desaturation;

                float _BorderOutterSizeX;
                float _BorderOutterSizeY;
                float _BorderInnerSizeX;
                float _BorderInnerSizeY;
                float _BorderOutterRound;

                float _BorderInnerSharpness;
                float _BorderOutterSharpness;

                float _CrtReflectionFalloff;
                float _CrtReflectionCurve;
                float _CrtReflectionRadius;
                float _CrtGlowAmount;
                float _BorderInnerDarkerAmount;

                float _Spread;
                float _Spread8;
                float _DitherScreenScale;

                float _MaxColorsRed;
                float _MaxColorsGreen;
                float _MaxColorsBlue;
            CBUFFER_END

            // Bayer matrices (set globally from C# each frame)
            uniform float _BrewedInk_Bayer4[16];
            uniform float _BrewedInk_Bayer8[64];

            // ---------------------------------------------------------------------------
            // Helpers  (identical math to the original CG shader)
            // ---------------------------------------------------------------------------
            float roundBox(float2 p, float2 b, float r)
            {
                return length(max(abs(p) - b, 0.0)) - r;
            }

            float2 borderReflect(float2 p, float r)
            {
                float eps = 0.0001;
                float2 epsx = float2(eps, 0.0);
                float2 epsy = float2(0.0, eps);
                float2 b = (1.0 + float2(r, r)) * 0.5;
                r /= 3.0;

                p -= 0.5;
                float2 normal = float2(
                    roundBox(p - epsx, b, r) - roundBox(p + epsx, b, r),
                    roundBox(p - epsy, b, r) - roundBox(p + epsy, b, r)) / eps;
                float d = roundBox(p, b, r);
                p += 0.5;
                return p + d * normal;
            }

            float2 CurvedSurface(float2 uv, float r)
            {
                return r * uv / sqrt(r * r - dot(uv, uv));
            }

            float2 crtCurve(float2 uv, float r)
            {
                r = 3.0 * r;
                uv = CurvedSurface(uv, r);
                uv = (uv / 2.0) + 0.5;
                return uv;
            }

            // ---------------------------------------------------------------------------
            // sampleColor – same logic as the original, using HLSL texture ops
            // ---------------------------------------------------------------------------
            float4 sampleColor(float2 screenUv, float2 warpedUv, float4 screenParams)
            {
                int n4 = 4;
                int x4 = (int)(screenUv.x * screenParams.x * _DitherScreenScale) % n4;
                int y4 = (int)(screenUv.y * screenParams.y * _DitherScreenScale) % n4;
                float m4 = _BrewedInk_Bayer4[y4 * n4 + x4] / (float)(n4 * n4) - 0.5;

                int n8 = 8;
                int x8 = (int)(screenUv.x * screenParams.x * _DitherScreenScale) % n8;
                int y8 = (int)(screenUv.y * screenParams.y * _DitherScreenScale) % n8;
                float m8 = _BrewedInk_Bayer8[y8 * n8 + x8] / (float)(n8 * n8) - 0.5;

                // In URP the blit source is _BlitTexture (injected by Blit.hlsl),
                // but the material property _MainTex works the same way after Blit().
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, warpedUv);
                col.rgb += m4 * _Spread + m8 * _Spread8;

                col.r = _MaxColorsRed   <= 0 ? col.r : floor(col.r * (_MaxColorsRed   - 1) + 0.5) / (_MaxColorsRed   - 1);
                col.g = _MaxColorsGreen <= 0 ? col.g : floor(col.g * (_MaxColorsGreen - 1) + 0.5) / (_MaxColorsGreen - 1);
                col.b = _MaxColorsBlue  <= 0 ? col.b : floor(col.b * (_MaxColorsBlue  - 1) + 0.5) / (_MaxColorsBlue  - 1);
                col.rgb = saturate(col.rgb);

                float grey = 0.21 * col.r + 0.71 * col.g + 0.07 * col.b;
                col.rgb = lerp(col.rgb, grey.xxx, _Desaturation);

                float t = _Time.z * _ColorScans.w;
                float s = (sin(screenParams.y * screenUv.y * _ColorScans.z + t) + 1.0) * _ColorScans.x + 1.0;
                float c = (cos(screenParams.y * screenUv.y * _ColorScans.z + t) + 1.0) * _ColorScans.y + 1.0;
                col.g  *= s;
                col.rb *= c;

                float2 absUv      = abs(warpedUv * 2.0 - 1.0);
                float2 invertAbsUv = 1.0 - absUv;
                float  vigSize    = lerp(0.0, 500.0, _VigSize);
                float2 v          = float2(vigSize / screenParams.x, vigSize / screenParams.y);
                float2 vig        = smoothstep(0.0, v, invertAbsUv);
                float  vigMask    = vig.x * vig.y;

                col *= vigMask;
                col  = saturate(col);
                return col;
            }

            // ---------------------------------------------------------------------------
            // Vertex – Blit.hlsl provides Varyings / Vert already,
            // but we redefine so the pass is self-contained with _MainTex UVs.
            // ---------------------------------------------------------------------------
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // Full-screen triangle / quad – already in clip space from URP blit
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                // Flip V on DX-style platforms (URP handles this automatically
                // when using Blit(), but we still guard here)
#if UNITY_UV_STARTS_AT_TOP
                output.uv.y = 1.0 - output.uv.y;
#endif
                return output;
            }

            // ---------------------------------------------------------------------------
            // Fragment – direct port of the original CG frag
            // ---------------------------------------------------------------------------
            float4 Frag(Varyings input) : SV_Target
            {
                float4 screenParams = _ScreenParams;

                float2 p = input.uv * 2.0 - 1.0;
                p *= _BorderZoom;
                p += p * dot(p, p) * _Curvature2;

                float2 borderUv = p;
                float boundOut = roundBox(borderUv,
                    float2(1.0 + _BorderOutterSizeX, 1.0 + _BorderOutterSizeY),
                    _BorderOutterRound) * lerp(5.0, 100.0, _BorderOutterSharpness);
                boundOut = saturate(boundOut);

                float innerBoarderScale = lerp(5.0, 100.0, _BorderInnerSharpness);
                float boundIn = roundBox(borderUv,
                    float2(1.0 - _BorderInnerSizeX, 1.0 - _BorderInnerSizeY),
                    _BorderOutterRound) * innerBoarderScale;
                boundIn = saturate(boundIn);

                float insideMask  = boundIn - boundOut;
                float outsideMask = boundOut;

                float insideArg = 4.0 * (1.0 - roundBox(borderUv,
                    float2(1.0 - _BorderInnerSizeX, 1.0 - _BorderInnerSizeY),
                    _BorderOutterRound) * lerp(1.0, 70.0, _CrtReflectionFalloff));
                insideArg = saturate(insideArg);

                float4 borderColor = SAMPLE_TEXTURE2D(_BorderTex,
                    sampler_BorderTex,
                    p * _BorderTex_ST.xy + _BorderTex_ST.zw);
                borderColor.rgb = lerp(borderColor.rgb * _BorderTint.rgb,
                    _BorderTint.rgb,
                    1.0 - _BorderTint.a);

                float2 uv          = p * (1.0 - _BorderOutterRound);
                float2 offset      = uv / _Curvature;
                float2 curvedSpace = uv + uv * offset * offset;
                float2 mappedUv    = curvedSpace * 0.5 + 0.5;

                float2 crt  = crtCurve(curvedSpace, _CrtReflectionCurve);
                float2 qUv  = borderReflect(crt, _CrtReflectionRadius);

                float4 qColor   = insideMask * insideArg * sampleColor(input.uv, qUv, screenParams);
                float4 col      = sampleColor(input.uv, mappedUv, screenParams);
                float  screenMask = 1.0 - boundIn;

                return col * screenMask
                     + (_CrtGlowAmount * qColor + _BorderInnerDarkerAmount * borderColor * insideMask)
                     + (borderColor * outsideMask);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
