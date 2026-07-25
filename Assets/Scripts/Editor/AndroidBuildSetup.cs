#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

/// <summary>
/// Editor helper: applies all Android build settings required for the 5v5 shooter.
/// Run via  Tools > Configure Android Build.
/// </summary>
public static class AndroidBuildSetup
{
    [MenuItem("Tools/Android/Configure Android Build Settings")]
    public static void Configure()
    {
        // ── SDK / NDK Versions ─────────────────────────────────────────────
        PlayerSettings.Android.minSdkVersion    = AndroidSdkVersions.AndroidApiLevel24; // Android 7.0
        PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel34; // Android 14

        // ── Architecture & Backend ─────────────────────────────────────────
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;

        // ── Build System ───────────────────────────────────────────────────
        EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;

        // ── Texture Compression ────────────────────────────────────────────
        // ASTC — best quality-to-size ratio on modern Android GPUs
        EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ASTC;

        // ── Code Stripping ─────────────────────────────────────────────────
        PlayerSettings.stripEngineCode = true;
        PlayerSettings.SetManagedStrippingLevel(BuildTargetGroup.Android, ManagedStrippingLevel.High);

        // ── Permissions ────────────────────────────────────────────────────
        // Internet required for Photon Fusion
        PlayerSettings.Android.forceInternetPermission = true;

        // ── Orientation ────────────────────────────────────────────────────
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
        PlayerSettings.allowedAutorotateToLandscapeLeft  = true;
        PlayerSettings.allowedAutorotateToLandscapeRight = true;
        PlayerSettings.allowedAutorotateToPortrait       = false;
        PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;

        // ── Misc ───────────────────────────────────────────────────────────
        PlayerSettings.Android.renderOutsideSafeArea = true;  // Full bleed on notched phones
        PlayerSettings.Android.blitType = AndroidBlitType.Auto;

        AssetDatabase.SaveAssets();

        Debug.Log("[AndroidBuildSetup] ✓ Android build settings configured:\n" +
                  "  Min SDK:      API 24 (Android 7)\n" +
                  "  Target SDK:   API 34 (Android 14)\n" +
                  "  Backend:      IL2CPP\n" +
                  "  Architecture: ARM64\n" +
                  "  Texture:      ASTC\n" +
                  "  Stripping:    High\n" +
                  "  Internet:     Enabled\n" +
                  "  Orientation:  Landscape");

        EditorUtility.DisplayDialog("Android Build Settings",
            "Settings applied!\n\n" +
            "• Min SDK: API 24 (Android 7)\n" +
            "• IL2CPP + ARM64\n" +
            "• ASTC texture compression\n" +
            "• Managed stripping: High\n" +
            "• Internet permission: ON\n" +
            "• Orientation: Landscape",
            "OK");
    }
}
#endif
