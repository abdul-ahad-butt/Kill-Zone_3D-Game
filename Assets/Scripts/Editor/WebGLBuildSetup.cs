#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Applies all WebGL-specific build settings required for the 5v5 shooter.
/// Run via  Tools > WebGL > Configure WebGL Build Settings.
/// </summary>
public static class WebGLBuildSetup
{
    [MenuItem("Tools/WebGL/Configure WebGL Build Settings")]
    public static void Configure()
    {
        // ── Compression ────────────────────────────────────────────────────
        // Brotli gives the best compression ratio (~15–20% smaller than gzip).
        // Requires the web server to serve Content-Encoding: br headers.
        // Enable decompression fallback so browsers without Brotli still work.
        PlayerSettings.WebGL.compressionFormat      = WebGLCompressionFormat.Brotli;
        PlayerSettings.WebGL.decompressionFallback  = true;

        // ── Memory ─────────────────────────────────────────────────────────
        // 512 MB is the recommended starting point for a networked 3D game.
        // Raise to 768/1024 if you hit out-of-memory crashes; lowering risks
        // heap fragmentation in long sessions.
        PlayerSettings.WebGL.memorySize = 512;

        // ── Exception Handling ─────────────────────────────────────────────
        // ExplicitlyThrownExceptionsOnly: crash stack traces for thrown
        // exceptions, but not for native IL errors — best perf trade-off.
        PlayerSettings.WebGL.exceptionSupport = WebGLExceptionSupport.ExplicitlyThrownExceptionsOnly;

        // ── Threading (IL2CPP) ─────────────────────────────────────────────
        // linkerTarget = Wasm strips unused IL2CPP code for smaller builds.
        // Threads in WebGL require SharedArrayBuffer; disable unless you've
        // verified your host sets the required COOP/COEP headers.
        PlayerSettings.WebGL.threadsSupport = false;

        // ── Data Caching ───────────────────────────────────────────────────
        // Cache the large data file in IndexedDB so repeat visits load faster.
        PlayerSettings.WebGL.dataCaching = true;

        // ── Template ───────────────────────────────────────────────────────
        PlayerSettings.WebGL.template = "APPLICATION:Default";

        // ── Colour Space ───────────────────────────────────────────────────
        if (PlayerSettings.colorSpace != ColorSpace.Linear)
        {
            PlayerSettings.colorSpace = ColorSpace.Linear;
            Debug.LogWarning("[WebGLBuildSetup] Colour space changed to Linear. " +
                             "Reimport textures flagged as sRGB if colours look washed out.");
        }

        // ── Stripping ──────────────────────────────────────────────────────
        PlayerSettings.stripEngineCode = true;
        PlayerSettings.SetManagedStrippingLevel(BuildTargetGroup.WebGL, ManagedStrippingLevel.High);

        // ── Scripting Backend (WebGL always uses IL2CPP) ───────────────────
        // This is forced by Unity; setting it explicitly avoids build warnings.
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.WebGL, ScriptingImplementation.IL2CPP);

        AssetDatabase.SaveAssets();

        string report =
            "WebGL Build Settings Configured!\n\n" +
            "• Compression:         Brotli  (fallback: enabled)\n" +
            "• Memory size:         512 MB\n" +
            "• Exceptions:          ExplicitlyThrown only\n" +
            "• Threads:             Disabled (no SharedArrayBuffer required)\n" +
            "• Data caching:        Enabled (IndexedDB)\n" +
            "• Colour space:        Linear\n" +
            "• Stripping:           High\n\n" +
            "⚠  Brotli requires the web server to send:\n" +
            "   Content-Encoding: br\n" +
            "   Cross-Origin-Opener-Policy: same-origin\n" +
            "   Cross-Origin-Embedder-Policy: require-corp\n\n" +
            "For local testing use  python -m http.server 8080  (gzip fallback applies).";

        Debug.Log("[WebGLBuildSetup] ✓ " + report);
        EditorUtility.DisplayDialog("WebGL Build Settings", report, "OK");
    }

    // ── Build Size Report ──────────────────────────────────────────────────

    [MenuItem("Tools/WebGL/Report Last Build Size")]
    public static void ReportBuildSize()
    {
        string buildPath = EditorUserBuildSettings.GetBuildLocation(BuildTarget.WebGL);
        if (string.IsNullOrEmpty(buildPath) || !System.IO.Directory.Exists(buildPath))
        {
            EditorUtility.DisplayDialog("Build Size Report",
                "No WebGL build found.\nBuild the project first via File > Build Settings > Build.", "OK");
            return;
        }

        long totalBytes = GetDirectorySize(new System.IO.DirectoryInfo(buildPath));
        string buildRoot = System.IO.Path.Combine(buildPath, "Build");

        string details = $"Build folder: {buildPath}\n\nTotal size: {FormatBytes(totalBytes)}\n";

        if (System.IO.Directory.Exists(buildRoot))
        {
            foreach (var f in System.IO.Directory.GetFiles(buildRoot))
            {
                var fi = new System.IO.FileInfo(f);
                details += $"\n  {fi.Name,-40}  {FormatBytes(fi.Length)}";
            }
        }

        details += "\n\n📶 Estimated load time on 20 Mbps connection:\n" +
                   $"  ~{totalBytes / (20_000_000 / 8f):F1} seconds\n\n" +
                   "Target: initial download < 150 MB for cellular users.\n" +
                   "If over budget, move large assets to an Addressables remote group.";

        Debug.Log("[WebGLBuildSetup] Build Size Report:\n" + details);
        EditorUtility.DisplayDialog("WebGL Build Size Report", details, "OK");
    }

    private static long GetDirectorySize(System.IO.DirectoryInfo dir)
    {
        long size = 0;
        foreach (var fi in dir.GetFiles("*", System.IO.SearchOption.AllDirectories))
            size += fi.Length;
        return size;
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes > 1_000_000) return $"{bytes / 1_000_000.0:F1} MB";
        if (bytes > 1_000)     return $"{bytes / 1_000.0:F1} KB";
        return $"{bytes} B";
    }
}
#endif
