#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Creates and configures a WebGL-specific URP quality level.
/// Run via  Tools > WebGL > Configure WebGL Quality Settings.
/// </summary>
public static class WebGLQualitySetup
{
    private const string WebGLUrpAssetPath   = "Assets/Settings/URP-WebGL.asset";
    private const string WebGLRendererPath   = "Assets/Settings/URP-WebGLRenderer.asset";
    private const string QualityLevelName    = "WebGL";

    [MenuItem("Tools/WebGL/Configure WebGL Quality Settings")]
    public static void Configure()
    {
        // ── 1. Create URP Forward Renderer ────────────────────────────────
        UniversalRendererData rendererData = CreateOrLoad<UniversalRendererData>(WebGLRendererPath);
        rendererData.renderingMode   = RenderingMode.Forward;
        rendererData.depthPrimingMode = DepthPrimingMode.Disabled;
        EditorUtility.SetDirty(rendererData);

        // ── 2. Create URP Pipeline Asset ──────────────────────────────────
        UniversalRenderPipelineAsset urpAsset =
            UniversalRenderPipelineAsset.Create(rendererData);
        AssetDatabase.CreateAsset(urpAsset, WebGLUrpAssetPath);

        // WebGL quality tuning — higher than mobile, still conservative
        urpAsset.shadowDistance        = 40f;
        urpAsset.shadowCascadeCount    = 2;      // 2 cascades OK for desktop-class GPUs
        urpAsset.msaaSampleCount       = 2;      // 2x MSAA — good quality, reasonable cost
        urpAsset.supportsHDR           = false;  // HDR adds memory pressure in WebGL
        urpAsset.renderScale           = 1.0f;
        urpAsset.supportsCameraDepthTexture  = false;
        urpAsset.supportsCameraOpaqueTexture = false;

        EditorUtility.SetDirty(urpAsset);
        AssetDatabase.SaveAssets();

        // ── 3. Create / Update Quality Level ──────────────────────────────
        int webglQualityIndex = FindOrCreateQualityLevel(QualityLevelName);

        QualitySettings.SetQualityLevel(webglQualityIndex, false);
        QualitySettings.renderPipeline = urpAsset;

        // Texture limits — 2048 max to balance quality vs. download size
        QualitySettings.masterTextureLimit       = 0;  // Full resolution
        QualitySettings.globalTextureMipmapLimit = 0;

        // Shadows
        QualitySettings.shadowDistance  = 40f;
        QualitySettings.shadowCascades  = 2;
        QualitySettings.shadows         = ShadowQuality.All; // Soft shadows on desktop GPU OK

        // LOD — keep full detail; LOD is less critical with WebGL bandwidth limits anyway
        QualitySettings.lodBias         = 1.0f;
        QualitySettings.maximumLODLevel = 0;

        // Skinning
        QualitySettings.skinWeights     = SkinWeights.FourBones;

        // Particles
        QualitySettings.particleRaycastBudget = 256;

        // Async upload — reduce stutter during texture streaming
        QualitySettings.asyncUploadTimeSlice  = 4;   // ms per frame
        QualitySettings.asyncUploadBufferSize = 64;  // MB

        // Target frame rate (browser controls actual frame rate via requestAnimationFrame)
        Application.targetFrameRate = 60;
        QualitySettings.vSyncCount  = 0; // Ignored on WebGL but keep consistent

        EditorUtility.SetDirty(QualitySettings.GetRenderPipelineAssetAt(webglQualityIndex));
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        string report =
            $"Quality level '{QualityLevelName}' configured!\n\n" +
            "• Shadow distance:  40\n" +
            "• Shadow cascades:  2  (soft shadows)\n" +
            "• MSAA:             2x\n" +
            "• HDR:              OFF\n" +
            "• Texture max:      2048\n" +
            "• LOD bias:         1.0 (full detail)\n" +
            "• 4-bone skinning\n\n" +
            $"URP Asset: {WebGLUrpAssetPath}\n\n" +
            "Select this quality level in ProjectSettings > Quality when building for WebGL.";

        Debug.Log("[WebGLQualitySetup] ✓ " + report);
        EditorUtility.DisplayDialog("WebGL Quality Settings", report, "OK");
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private static T CreateOrLoad<T>(string path) where T : ScriptableObject
    {
        T existing = AssetDatabase.LoadAssetAtPath<T>(path);
        if (existing != null) return existing;
        T asset = ScriptableObject.CreateInstance<T>();
        AssetDatabase.CreateAsset(asset, path);
        return asset;
    }

    private static int FindOrCreateQualityLevel(string levelName)
    {
        string[] names = QualitySettings.names;
        for (int i = 0; i < names.Length; i++)
            if (names[i] == levelName) return i;

        Debug.LogWarning($"[WebGLQualitySetup] Quality level '{levelName}' not found. " +
                         "Create it in ProjectSettings > Quality, name it exactly '" +
                         levelName + "', then re-run this tool.");
        return QualitySettings.GetQualityLevel();
    }
}
#endif
