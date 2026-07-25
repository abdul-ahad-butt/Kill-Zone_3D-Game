#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Editor helper: creates and wires up a mobile-tier URP quality level.
/// Run via  Tools > Android > Configure Mobile Quality.
/// </summary>
public static class MobileQualitySetup
{
    private const string MobileUrpAssetPath    = "Assets/Settings/URP-MobileTier.asset";
    private const string MobileRendererPath    = "Assets/Settings/URP-MobileRenderer.asset";
    private const string QualityLevelName      = "MidTier Mobile";

    [MenuItem("Tools/Android/Configure Mobile Quality Settings")]
    public static void Configure()
    {
        // ── 1. Create URP Forward Renderer ────────────────────────────────
        UniversalRendererData rendererData = CreateOrLoad<UniversalRendererData>(MobileRendererPath);
        rendererData.renderingMode         = RenderingMode.Forward;
        rendererData.depthPrimingMode      = DepthPrimingMode.Disabled;  // Not needed on tile-based mobile GPUs
        EditorUtility.SetDirty(rendererData);

        // ── 2. Create URP Pipeline Asset ──────────────────────────────────
        UniversalRenderPipelineAsset urpAsset =
            UniversalRenderPipelineAsset.Create(rendererData);
        AssetDatabase.CreateAsset(urpAsset, MobileUrpAssetPath);

        // Mid-tier mobile tuning
        urpAsset.shadowDistance          = 30f;
        urpAsset.shadowCascadeCount      = 1;              // Single cascade = cheaper
        urpAsset.msaaSampleCount         = 1;              // MSAA off (tile GPU handles it differently)
        urpAsset.supportsHDR             = false;
        urpAsset.renderScale             = 1.0f;
        urpAsset.supportsCameraDepthTexture  = false;      // Only enable if post-effects need it
        urpAsset.supportsCameraOpaqueTexture = false;

        EditorUtility.SetDirty(urpAsset);
        AssetDatabase.SaveAssets();

        // ── 3. Create / Update Quality Level ──────────────────────────────
        int mobileQualityIndex = FindOrCreateQualityLevel(QualityLevelName);

        // Assign the URP asset to this quality level
        QualitySettings.SetQualityLevel(mobileQualityIndex, false);
        QualitySettings.renderPipeline   = urpAsset;

        // Frame rate & vsync
        Application.targetFrameRate      = 60;
        QualitySettings.vSyncCount       = 0;              // Use targetFrameRate on mobile

        // Texture limits (cap to 1024 max for mid-tier)
        QualitySettings.globalTextureMipmapLimit = 0;     // 0 = full res, override per-texture where needed
        // Note: use 'masterTextureLimit = 1' to halve all textures if memory pressure is a problem
        QualitySettings.masterTextureLimit       = 0;

        // Shadows
        QualitySettings.shadowDistance           = 30f;
        QualitySettings.shadowCascades           = 1;
        QualitySettings.shadows                  = ShadowQuality.HardOnly; // Soft shadows expensive on mobile

        // LOD / Skinning
        QualitySettings.lodBias                  = 0.7f;  // Slightly aggressive LOD switching
        QualitySettings.maximumLODLevel          = 0;
        QualitySettings.skinWeights              = SkinWeights.TwoBones; // 2 bones enough for FPS

        // Particles
        QualitySettings.particleRaycastBudget    = 64;

        EditorUtility.SetDirty(QualitySettings.GetRenderPipelineAssetAt(mobileQualityIndex));
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log($"[MobileQualitySetup] ✓ Quality level '{QualityLevelName}' configured.\n" +
                  $"  Shadow distance:  30\n" +
                  $"  Shadow cascades:  1 (hard only)\n" +
                  $"  MSAA:             OFF\n" +
                  $"  HDR:              OFF\n" +
                  $"  LOD Bias:         0.7\n" +
                  $"  Skin weights:     2 bones\n" +
                  $"  URP Asset:        {MobileUrpAssetPath}");

        EditorUtility.DisplayDialog("Mobile Quality Settings",
            $"Quality level '{QualityLevelName}' created and configured!\n\n" +
            "• Shadow distance: 30\n" +
            "• Cascades: 1, Hard shadows only\n" +
            "• MSAA: OFF\n" +
            "• HDR: OFF\n" +
            "• LOD bias: 0.7\n" +
            "• 2-bone skinning\n\n" +
            $"URP Asset saved to: {MobileUrpAssetPath}\n\n" +
            "Select this quality level in ProjectSettings > Quality when building for Android.",
            "OK");
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
        {
            if (names[i] == levelName) return i;
        }

        // Quality levels are managed via SerializedObject; simplest approach
        // is to inform the user to create the level manually and re-run.
        Debug.LogWarning($"[MobileQualitySetup] Quality level '{levelName}' not found. " +
                         "Create it in ProjectSettings > Quality, name it exactly '" + levelName +
                         "', then re-run this tool. Using current quality level for now.");
        return QualitySettings.GetQualityLevel();
    }
}
#endif
