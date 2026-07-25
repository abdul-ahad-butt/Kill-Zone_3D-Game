#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

/// <summary>
/// Editor window listing exactly what to measure in the Unity Profiler and
/// Android GPU frame capture for a mid-tier mobile performance check.
/// Open via  Tools > Android > Show Mobile Profiling Guide.
/// </summary>
public class MobileProfilingGuide : EditorWindow
{
    private Vector2 _scroll;

    [MenuItem("Tools/Android/Show Mobile Profiling Guide")]
    public static void ShowWindow()
    {
        MobileProfilingGuide window = GetWindow<MobileProfilingGuide>("Mobile Profiling Guide");
        window.minSize = new Vector2(520, 640);
        window.Show();
    }

    private void OnGUI()
    {
        _scroll = EditorGUILayout.BeginScrollView(_scroll);

        H1("📱 Mobile Profiling Guide — 5v5 Tactical Shooter");
        Note("Target device: mid-range Android (e.g. Snapdragon 695 / Mali-G57). Goal: 60 fps stable.");

        // ── Unity Profiler ─────────────────────────────────────────────────
        H2("1. Unity Profiler  (Window > Analysis > Profiler)");

        H3("CPU — frame budget 16.6 ms @ 60 fps");
        BulletBudget("Total frame time",            "< 16 ms",   "Main thread. If over, check CPU section.");
        BulletBudget("Physics (FixedUpdate)",        "< 2 ms",    "Mostly CharacterController + raycasts. Keep collider counts low.");
        BulletBudget("Scripts",                      "< 4 ms",    "MatchManager, Health, WeaponController updates. Watch for GC allocs.");
        BulletBudget("Rendering (CPU side)",         "< 5 ms",    "Draw call submission. Watch SetPass calls > 100.");
        BulletBudget("GC.Collect",                   "0 spikes",  "Any GC spike > 1 ms will cause a visible hitch. Fix hot-path allocs.");

        H3("Rendering");
        BulletBudget("Draw calls",                   "< 150",     "Use GPU instancing on player/weapon meshes.");
        BulletBudget("SetPass calls",                "< 60",      "Group materials. Use URP batching (SRP Batcher must be ON).");
        BulletBudget("Triangles",                    "< 300 K",   "Per frame. Use LOD groups on players and environment.");
        BulletBudget("Shadow casters",               "< 30",      "Shadow distance is already set to 30 m; cull aggressively.");

        H3("Memory");
        BulletBudget("Total RAM",                    "< 800 MB",  "Mid-tier Android kills apps over 900 MB. Check Textures + Meshes.");
        BulletBudget("Texture memory",               "< 200 MB",  "Use ASTC 6x6 for environment, ASTC 4x4 for characters.");
        BulletBudget("GC heap",                      "< 50 MB",   "Profile > Memory. Large heap = frequent GC pauses.");

        // ── Network / Fusion ───────────────────────────────────────────────
        H2("2. Photon Fusion — Networking");
        BulletNote("Simulation time per tick",       "Monitor via Fusion's stats overlay (Runner.Simulation.Stats). Keep < 4 ms.");
        BulletNote("Received bytes/frame",           "Watch for spikes; reduce [Networked] property count where possible.");
        BulletNote("Input RTT",                      "< 80 ms for playable feel. Check Fusion dashboard → Session → Latency.");

        // ── Android GPU Frame Capture ──────────────────────────────────────
        H2("3. Android GPU Frame Capture  (Android Studio → Profiler → GPU)");
        BulletNote("GPU frame time",                 "< 16 ms. Tile-based GPUs (Mali/Adreno) handle overdraw differently from desktop.");
        BulletNote("Overdraw",                       "Transparent objects (e.g. muzzle flash particles) are the biggest GPU cost. Cap particle count.");
        BulletNote("Shader complexity",              "Use URP Simple Lit (not Lit) on environment meshes. Lit is ~2× more expensive.");
        BulletNote("Texture bandwidth",              "ASTC reduces bandwidth vs ETC2. Confirm ASTC is selected in Build Settings.");

        H2("4. Quick Wins If Frame Rate Is Under Target");
        Bullet("Enable SRP Batcher in URP Asset (Universal Render Pipeline > Advanced > SRP Batcher).");
        Bullet("Enable GPU Instancing on the Player and Weapon materials.");
        Bullet("Reduce Directional Light shadow resolution to 512 or 1024.");
        Bullet("Disable real-time shadows entirely on Spot/Point lights (only 1 directional needed).");
        Bullet("Reduce Particle System Max Particles on muzzle flash and impact effects.");
        Bullet("Cap particle VFX pool via Object Pooling (prevents Instantiate/Destroy GC spikes).");
        Bullet("If Bloom/Depth-of-Field are in your Volume, remove them on Android — very expensive.");
        Bullet("Use Render Scale < 1.0 (e.g. 0.85) in URP Asset as a last resort.");

        H2("5. Build Size Targets");
        BulletBudget("Initial APK / AAB download", "< 150 MB",  "Google Play threshold for cellular downloads.");
        BulletBudget("Installed size on device",   "< 400 MB",  "Acceptable for a mid-core shooter.");
        Note("If over budget: enable Addressables for large textures/audio, ship them as a patch instead of bundling in the APK.");

        EditorGUILayout.EndScrollView();
    }

    // ── GUI Helpers ───────────────────────────────────────────────────────

    private void H1(string text)
    {
        EditorGUILayout.Space(8);
        GUIStyle s = new GUIStyle(EditorStyles.boldLabel);
        s.fontSize = 14;
        EditorGUILayout.LabelField(text, s);
        Separator();
    }

    private void H2(string text)
    {
        EditorGUILayout.Space(8);
        GUIStyle s = new GUIStyle(EditorStyles.boldLabel);
        s.fontSize = 12;
        EditorGUILayout.LabelField(text, s);
    }

    private void H3(string text)
    {
        EditorGUILayout.Space(4);
        EditorGUILayout.LabelField(text, EditorStyles.boldLabel);
    }

    private void Bullet(string text)
    {
        EditorGUILayout.LabelField("  •  " + text, EditorStyles.wordWrappedLabel);
    }

    private void BulletBudget(string metric, string budget, string note)
    {
        EditorGUILayout.LabelField($"  •  {metric,-30}  Target: {budget,-12}  — {note}", EditorStyles.wordWrappedLabel);
    }

    private void BulletNote(string metric, string note)
    {
        EditorGUILayout.LabelField($"  •  {metric,-30}  {note}", EditorStyles.wordWrappedLabel);
    }

    private void Note(string text)
    {
        GUIStyle s = new GUIStyle(EditorStyles.helpBox);
        s.wordWrap = true;
        EditorGUILayout.LabelField(text, s);
    }

    private void Separator()
    {
        Rect r = EditorGUILayout.GetControlRect(false, 1);
        EditorGUI.DrawRect(r, new Color(0.5f, 0.5f, 0.5f, 0.5f));
    }
}
#endif
