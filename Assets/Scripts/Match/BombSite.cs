using UnityEngine;

[RequireComponent(typeof(Collider))]
public class BombSite : MonoBehaviour
{
    public string siteName = "A"; // e.g. "A" or "B"
    
    private void Start()
    {
        GetComponent<Collider>().isTrigger = true;
    }
}
