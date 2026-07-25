#if UNITY_EDITOR
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Scans Assets/Scripts/ for patterns that are incompatible with (or problematic on) WebGL.
/// Run via  Tools > WebGL > Run Compatibility Audit.
/// Results are printed to the Console with clickable file references.
/// </summary>
public static class WebGLCompatibilityAudit
{
    // ── Patterns to flag ──────────────────────────────────────────────────
    private static readonly (string pattern, string severity, string explanation)[] Checks =
    {
        // Threading
        (@"\bnew\s+Thread\s*\(",              "ERROR",   "Thread not supported on WebGL. Use Coroutines or async/await with SynchronizationContext."),
        (@"\bTask\.Run\s*\(",                 "ERROR",   "Task.Run uses ThreadPool which is unavailable on WebGL. Use async/await on the main thread or Coroutines."),
        (@"\bThread\.Sleep\s*\(",             "ERROR",   "Thread.Sleep blocks the browser's JS thread. Use yield return new WaitForSeconds() instead."),

        // Networking (raw sockets)
        (@"\bSystem\.Net\.Sockets\b",         "ERROR",   "Raw sockets are not available in WebGL. Use Photon Fusion (WebSocket transport) or UnityWebRequest."),
        (@"\bTcpClient\b|\bUdpClient\b",      "ERROR",   "TcpClient/UdpClient are not supported in WebGL."),

        // File I/O
        (@"\bFile\.\b",                       "WARNING", "System.IO.File is not available in WebGL. Use PlayerPrefs, UnityWebRequest, or Addressables."),
        (@"\bFileStream\b",                   "WARNING", "FileStream not available in WebGL. Use alternative persistence."),
        (@"\bStreamingAssets\b",              "WARNING", "StreamingAssets paths must be loaded via UnityWebRequest on WebGL, not File.ReadAll*."),

        // Application
        (@"\bApplication\.Quit\b",            "WARNING", "Application.Quit() is a no-op on WebGL. Guard with #if !UNITY_WEBGL."),

        // Native plugins
        (@"\[DllImport\b",                    "ERROR",   "Native plugins (DllImport) are not supported in WebGL unless compiled to Wasm."),

        // Reflection
        (@"\bSystem\.Reflection\.Emit\b",     "ERROR",   "Reflection.Emit is not available in IL2CPP/WebGL builds."),

        // Unsafe / Pointers
        (@"\bunsafe\b.*\bstackalloc\b",       "WARNING", "stackalloc in unsafe code may cause issues in WebGL Wasm. Test carefully."),

        // Unity-specific
        (@"\bScreenCapture\.CaptureScreenshot\b", "WARNING", "CaptureScreenshot is not supported on WebGL."),
        (@"\bMicrophone\b",                   "WARNING", "Microphone access requires explicit browser permission on WebGL and may be blocked."),
        (@"\bWebcamTexture\b",                "WARNING", "WebcamTexture requires browser permission on WebGL."),
        (@"\bNavMesh\.CalculatePath\b",       "INFO",    "NavMesh.CalculatePath is synchronous on WebGL and may stall the frame. Consider async nav or precomputed paths."),
        (@"\bAsyncOperation\b",               "INFO",    "Async scene loads work on WebGL but progress updates may appear coarser than on native builds."),
    };

    [MenuItem("Tools/WebGL/Run Compatibility Audit")]
    public static void RunAudit()
    {
        string scriptsRoot = Path.Combine(Application.dataPath, "Scripts");
        if (!Directory.Exists(scriptsRoot))
        {
            Debug.LogWarning("[WebGLAudit] Assets/Scripts/ not found. Adjust the path if your scripts live elsewhere.");
            return;
        }

        var files = Directory.GetFiles(scriptsRoot, "*.cs", SearchOption.AllDirectories);

        int errorCount   = 0;
        int warningCount = 0;
        int infoCount    = 0;
        var sb = new StringBuilder();
        sb.AppendLine("═══════════════════════════════════════════════════════════");
        sb.AppendLine("  WebGL Compatibility Audit Report");
        sb.AppendLine($"  Scanned {files.Length} C# files in Assets/Scripts/");
        sb.AppendLine("═══════════════════════════════════════════════════════════");

        bool anyIssue = false;

        foreach (string filePath in files)
        {
            string[] lines    = File.ReadAllLines(filePath);
            string relPath    = "Assets" + filePath.Substring(Application.dataPath.Length).Replace('\\', '/');
            var fileIssues    = new List<string>();

            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];

                // Skip preprocessor-guarded lines (simple heuristic)
                if (line.TrimStart().StartsWith("#if")) continue;

                foreach (var (pattern, severity, explanation) in Checks)
                {
                    if (Regex.IsMatch(line, pattern))
                    {
                        string tag = severity switch
                        {
                            "ERROR"   => "🔴 ERROR",
                            "WARNING" => "🟡 WARNING",
                            _         => "🔵 INFO"
                        };

                        fileIssues.Add($"  {tag}  Line {i + 1}: {line.Trim()}\n         → {explanation}");

                        if (severity == "ERROR")        errorCount++;
                        else if (severity == "WARNING") warningCount++;
                        else                            infoCount++;

                        anyIssue = true;
                    }
                }
            }

            if (fileIssues.Count > 0)
            {
                sb.AppendLine($"\n▶ {relPath}");
                foreach (var issue in fileIssues)
                    sb.AppendLine(issue);
            }
        }

        sb.AppendLine("\n═══════════════════════════════════════════════════════════");
        sb.AppendLine($"  Summary: {errorCount} error(s)  |  {warningCount} warning(s)  |  {infoCount} info");

        if (!anyIssue)
            sb.AppendLine("  ✅ No issues found — codebase looks WebGL-compatible!");
        else
            sb.AppendLine("  Fix all 🔴 ERRORs before publishing. 🟡 WARNINGs may cause subtle bugs.");

        sb.AppendLine("═══════════════════════════════════════════════════════════");

        // Log at appropriate level so Unity Console filter icons are correct
        if (errorCount > 0)
            Debug.LogError("[WebGLAudit]\n" + sb);
        else if (warningCount > 0)
            Debug.LogWarning("[WebGLAudit]\n" + sb);
        else
            Debug.Log("[WebGLAudit]\n" + sb);

        EditorUtility.DisplayDialog(
            "WebGL Compatibility Audit",
            $"Audit complete!\n\n" +
            $"🔴 Errors:   {errorCount}\n" +
            $"🟡 Warnings: {warningCount}\n" +
            $"🔵 Info:     {infoCount}\n\n" +
            "See the Console for the full report with file and line numbers.",
            "OK");
    }
}
#endif
