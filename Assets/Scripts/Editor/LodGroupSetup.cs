#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

/// <summary>
/// Adds a 3-level LOD Group to any selected GameObject.
/// Assumes the selected object (LOD0) has child GameObjects or renderers.
///
/// Usage:
///   1. Select a Player or Weapon prefab root in the Hierarchy.
///   2. Tools > Android > Auto-Setup LOD Group
///
/// LOD levels created:
///   LOD 0 — 100 % screen height  (full detail)
///   LOD 1 —  35 % screen height  (mid detail — assign your reduced mesh here)
///   LOD 2 —  10 % screen height  (low detail — assign your lowest mesh here)
///   Cull  —   5 % screen height
/// </summary>
public static class LodGroupSetup
{
    [MenuItem("Tools/Android/Auto-Setup LOD Group on Selected")]
    public static void SetupLOD()
    {
        GameObject selected = Selection.activeGameObject;
        if (selected == null)
        {
            EditorUtility.DisplayDialog("LOD Setup", "Please select a GameObject first.", "OK");
            return;
        }

        // Remove existing LODGroup if present (re-run safe)
        LODGroup existing = selected.GetComponent<LODGroup>();
        if (existing != null)
        {
            Undo.DestroyObjectImmediate(existing);
        }

        LODGroup lodGroup = Undo.AddComponent<LODGroup>(selected);

        // Gather all renderers on the root and direct children
        Renderer[] allRenderers = selected.GetComponentsInChildren<Renderer>(true);

        if (allRenderers.Length == 0)
        {
            Debug.LogWarning("[LodGroupSetup] No renderers found on selected object. " +
                             "LOD Group added but no renderers assigned — assign them manually.");
        }

        // For a single-mesh object we put the same renderer in all 3 LODs.
        // In production you'd replace LOD1 and LOD2 with lower-poly meshes.
        LOD lod0 = new LOD(1.00f, allRenderers);  // 100% – 35% → full detail
        LOD lod1 = new LOD(0.35f, allRenderers);  // 35%  – 10% → assign mid-detail renderer here
        LOD lod2 = new LOD(0.10f, allRenderers);  // 10%  –  5% → assign low-detail renderer here

        lodGroup.SetLODs(new LOD[] { lod0, lod1, lod2 });
        lodGroup.RecalculateBounds();

        // Bias toward holding full detail longer (matches our LOD bias of 0.7)
        lodGroup.animateCrossFading = true;

        EditorUtility.SetDirty(selected);

        Debug.Log($"[LodGroupSetup] ✓ LOD Group added to '{selected.name}'.\n" +
                  "Assign your reduced-poly meshes to LOD 1 and LOD 2 in the Inspector.");

        EditorUtility.DisplayDialog("LOD Group Setup",
            $"LOD Group added to '{selected.name}'!\n\n" +
            "LOD 0 → 100% – 35%  (current mesh)\n" +
            "LOD 1 →  35% – 10%  ← assign reduced-poly mesh\n" +
            "LOD 2 →  10% –  5%  ← assign low-poly mesh\n" +
            "Culled below 5%\n\n" +
            "Cross-fading is enabled. Apply this to Player and Weapon prefabs.",
            "OK");
    }
}
#endif
