// Addressables setup is only available when the Addressables package is installed.
// Install via: Window > Package Manager > + > Add by name: com.unity.addressables
#if UNITY_EDITOR && UNITY_ADDRESSABLES

using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
using UnityEngine;

/// <summary>
/// Sets up Addressable groups optimised for WebGL:
///   • "LocalContent"  — always bundled in the initial build (scenes, SOs, UI prefabs)
///   • "RemoteContent" — served from a CDN, downloaded on demand (large textures, audio)
///
/// Run via  Tools > WebGL > Setup Addressables for WebGL.
/// </summary>
public static class AddressablesSetup
{
    private const string RemoteGroupName = "RemoteContent";
    private const string LocalGroupName  = "LocalContent";

    // Replace with your actual CDN URL before shipping
    private const string RemoteLoadPath  = "https://your-cdn.example.com/[BuildTarget]";
    private const string RemoteBuildPath = "ServerData/[BuildTarget]";

    [MenuItem("Tools/WebGL/Setup Addressables for WebGL")]
    public static void Setup()
    {
        AddressableAssetSettings settings = AddressableAssetSettingsDefaultObject.GetSettings(true);
        if (settings == null)
        {
            EditorUtility.DisplayDialog("Addressables Setup",
                "Could not find or create Addressable Settings.\n" +
                "Please open Window > Asset Management > Addressables > Groups first.", "OK");
            return;
        }

        // ── Profile ───────────────────────────────────────────────────────
        AddressableAssetProfileSettings profiles = settings.profileSettings;
        string webglProfileId = profiles.GetProfileId("WebGL");

        if (string.IsNullOrEmpty(webglProfileId))
        {
            webglProfileId = profiles.AddProfile("WebGL", settings.activeProfileId);
        }

        profiles.SetValue(webglProfileId, AddressableAssetSettings.kRemoteLoadPath,  RemoteLoadPath);
        profiles.SetValue(webglProfileId, AddressableAssetSettings.kRemoteBuildPath, RemoteBuildPath);
        settings.activeProfileId = webglProfileId;

        // ── Local Content Group ───────────────────────────────────────────
        AddressableAssetGroup localGroup = settings.FindGroup(LocalGroupName)
                                        ?? settings.CreateGroup(LocalGroupName, false, false, true,
                                               new System.Collections.Generic.List<AddressableAssetGroupSchema>());

        var localBundled = localGroup.GetSchema<BundledAssetGroupSchema>()
                        ?? localGroup.AddSchema<BundledAssetGroupSchema>();

        localBundled.BuildPath.SetVariableByName(settings, AddressableAssetSettings.kLocalBuildPath);
        localBundled.LoadPath.SetVariableByName(settings,  AddressableAssetSettings.kLocalLoadPath);
        localBundled.BundleMode            = BundledAssetGroupSchema.BundlePackingMode.PackTogether;
        localBundled.Compression           = BundledAssetGroupSchema.BundleCompressionMode.LZ4;
        localBundled.UseAssetBundleCache   = true;

        // ── Remote Content Group ──────────────────────────────────────────
        AddressableAssetGroup remoteGroup = settings.FindGroup(RemoteGroupName)
                                          ?? settings.CreateGroup(RemoteGroupName, false, false, true,
                                                 new System.Collections.Generic.List<AddressableAssetGroupSchema>());

        var remoteBundled = remoteGroup.GetSchema<BundledAssetGroupSchema>()
                          ?? remoteGroup.AddSchema<BundledAssetGroupSchema>();

        remoteBundled.BuildPath.SetVariableByName(settings, AddressableAssetSettings.kRemoteBuildPath);
        remoteBundled.LoadPath.SetVariableByName(settings,  AddressableAssetSettings.kRemoteLoadPath);
        remoteBundled.BundleMode            = BundledAssetGroupSchema.BundlePackingMode.PackSeparately;
        remoteBundled.Compression           = BundledAssetGroupSchema.BundleCompressionMode.LZ4;
        remoteBundled.UseAssetBundleCache   = true;
        remoteBundled.RetryCount            = 3;

        // ── Global Settings ───────────────────────────────────────────────
        settings.BuildRemoteCatalog         = true;   // Needed for remote groups to work
        settings.DisableCatalogUpdateOnStartup = false;

        EditorUtility.SetDirty(settings);
        AssetDatabase.SaveAssets();

        string report =
            "Addressables configured for WebGL!\n\n" +
            $"Profile: 'WebGL'\n\n" +
            $"'{LocalGroupName}' group\n" +
            "  • Bundled, LZ4 compression\n" +
            "  • Always included in build\n" +
            "  → Add: scenes, weapon SOs, UI prefabs, core audio\n\n" +
            $"'{RemoteGroupName}' group\n" +
            "  • Bundled separately per asset\n" +
            "  • Served from CDN on demand\n" +
            $"  • Remote load URL: {RemoteLoadPath}\n" +
            $"  • Build output:    {RemoteBuildPath}/\n" +
            "  → Add: large environment textures, map audio, cutscenes\n\n" +
            "Next steps:\n" +
            "1. Mark large assets as Addressable in the Inspector.\n" +
            "2. Drag them into the RemoteContent group in the Addressables Groups window.\n" +
            "3. Build the remote content:  Window > Asset Management > Addressables > Build > Build Player Content.\n" +
            "4. Upload the ServerData/WebGL/ folder to your CDN.\n" +
            "5. Replace the placeholder RemoteLoadPath with your real CDN URL and rebuild.";

        Debug.Log("[AddressablesSetup] ✓ " + report);
        EditorUtility.DisplayDialog("Addressables Setup", report, "OK");
    }
}

#elif UNITY_EDITOR

// Stub so the menu item appears even before Addressables is installed
using UnityEditor;
using UnityEngine;

public static class AddressablesSetup
{
    [MenuItem("Tools/WebGL/Setup Addressables for WebGL")]
    public static void Setup()
    {
        EditorUtility.DisplayDialog("Addressables Not Installed",
            "The Unity Addressables package is not installed.\n\n" +
            "Install it via:\n" +
            "  Window > Package Manager > +\n" +
            "  Add by name:  com.unity.addressables\n\n" +
            "Then re-run this tool.", "OK");
    }
}
#endif
