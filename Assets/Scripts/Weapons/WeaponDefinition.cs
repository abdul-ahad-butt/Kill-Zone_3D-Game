using UnityEngine;

[CreateAssetMenu(fileName = "New Weapon", menuName = "Game/Weapon Definition")]
public class WeaponDefinition : ScriptableObject
{
    public string weaponName;
    public int damage;
    public float fireRate;
    public int magSize;
    public float reloadTime;
    public float range;
    public GameObject modelPrefab;
}
