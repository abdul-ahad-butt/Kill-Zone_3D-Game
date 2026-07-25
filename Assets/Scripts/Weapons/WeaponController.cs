using Fusion;
using System;
using System.Collections;
using UnityEngine;

public class WeaponController : NetworkBehaviour
{
    [Header("Loadout")]
    public WeaponDefinition currentWeapon;
    private int currentAmmo;
    private bool isReloading = false;
    private float nextTimeToFire = 0f;

    [Header("References")]
    public Camera playerCamera;
    public ParticleSystem muzzleFlash;
    public GameObject impactEffectPrefab;
    public AudioSource shootSound;

    public event Action<int, int> OnAmmoChanged;

    public void EquipWeapon(WeaponDefinition newWeapon)
    {
        currentWeapon = newWeapon;
        currentAmmo = currentWeapon.magSize;
        isReloading = false;
        OnAmmoChanged?.Invoke(currentAmmo, currentWeapon.magSize);
    }

    public override void Spawned()
    {
        if (currentWeapon != null)
        {
            EquipWeapon(currentWeapon);
        }
    }

    public override void FixedUpdateNetwork()
    {
        if (currentWeapon == null || isReloading) return;

        if (GetInput(out NetworkInputData input))
        {
            if (currentAmmo <= 0)
            {
                if (!isReloading) StartCoroutine(Reload());
                return;
            }

            if (input.buttons.IsSet(NetworkInputData.BUTTON_FIRE) && Runner.SimulationTime >= nextTimeToFire)
            {
                nextTimeToFire = Runner.SimulationTime + currentWeapon.fireRate;

                // Client-side prediction: instant VFX and ammo decrement for responsiveness
                currentAmmo--;
                OnAmmoChanged?.Invoke(currentAmmo, currentWeapon.magSize);
                if (muzzleFlash != null) muzzleFlash.Play();
                if (shootSound != null) shootSound.Play();

                // Tell server to resolve damage authoritatively
                if (HasInputAuthority)
                {
                    Rpc_FireWeapon(playerCamera.transform.position, playerCamera.transform.forward);
                }
            }
        }
    }

    [Rpc(RpcSources.InputAuthority, RpcTargets.StateAuthority)]
    public void Rpc_FireWeapon(Vector3 aimPosition, Vector3 aimDirection)
    {
        // Server-authoritative hit registration
        RaycastHit hit;
        if (Physics.Raycast(aimPosition, aimDirection, out hit, currentWeapon.range))
        {
            Health targetHealth = hit.transform.GetComponent<Health>();
            if (targetHealth != null)
            {
                // Pass this object as the attacker for kill credit
                targetHealth.TakeDamage(currentWeapon.damage, Object);
            }

            if (impactEffectPrefab != null)
            {
                GameObject impactGO = Instantiate(impactEffectPrefab, hit.point, Quaternion.LookRotation(hit.normal));
                Destroy(impactGO, 2f);
            }
        }
    }

    IEnumerator Reload()
    {
        isReloading = true;
        yield return new WaitForSeconds(currentWeapon.reloadTime);
        currentAmmo = currentWeapon.magSize;
        OnAmmoChanged?.Invoke(currentAmmo, currentWeapon.magSize);
        isReloading = false;
    }
}
