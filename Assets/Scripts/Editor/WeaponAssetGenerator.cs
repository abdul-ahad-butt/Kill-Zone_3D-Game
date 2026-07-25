#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class WeaponAssetGenerator
{
    [MenuItem("Tools/Generate Default Weapons")]
    public static void GenerateWeapons()
    {
        CreateWeapon("Rifle", 30, 0.1f, 30, 2f, 100f);
        CreateWeapon("SMG", 20, 0.08f, 30, 1.5f, 50f);
        CreateWeapon("Pistol", 15, 0.2f, 12, 1f, 30f);

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("Generated Default Weapons in Assets/ScriptableObjects/Weapons/");
    }

    private static void CreateWeapon(string name, int damage, float fireRate, int magSize, float reloadTime, float range)
    {
        string path = $"Assets/ScriptableObjects/Weapons/{name}.asset";
        
        // Ensure folder exists
        if (!AssetDatabase.IsValidFolder("Assets/ScriptableObjects"))
            AssetDatabase.CreateFolder("Assets", "ScriptableObjects");
        if (!AssetDatabase.IsValidFolder("Assets/ScriptableObjects/Weapons"))
            AssetDatabase.CreateFolder("Assets/ScriptableObjects", "Weapons");

        WeaponDefinition asset = AssetDatabase.LoadAssetAtPath<WeaponDefinition>(path);
        if (asset == null)
        {
            asset = ScriptableObject.CreateInstance<WeaponDefinition>();
            AssetDatabase.CreateAsset(asset, path);
        }

        asset.weaponName = name;
        asset.damage = damage;
        asset.fireRate = fireRate;
        asset.magSize = magSize;
        asset.reloadTime = reloadTime;
        asset.range = range;

        EditorUtility.SetDirty(asset);
    }
}
#endif
