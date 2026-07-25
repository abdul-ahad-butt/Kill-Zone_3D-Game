using Fusion;
using UnityEngine;
using System;

public class Health : NetworkBehaviour
{
    public int maxHealth = 100;

    [Networked]
    private int currentHealth { get; set; }

    public bool isPlayer = false;

    // Events for UI and MatchManager to subscribe to
    public event Action<int, int> OnHealthChanged;
    public event Action OnDeath;

    private ChangeDetector _changeDetector;

    public override void Spawned()
    {
        _changeDetector = GetChangeDetector(ChangeDetector.Source.SimulationState);

        if (HasStateAuthority)
        {
            currentHealth = maxHealth;
        }

        // Initial UI update
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
    }

    public override void Render()
    {
        foreach (var change in _changeDetector.DetectChanges(this))
        {
            switch (change)
            {
                case nameof(currentHealth):
                    OnHealthChanged?.Invoke(currentHealth, maxHealth);
                    if (currentHealth <= 0)
                    {
                        Die(null);
                    }
                    break;
            }
        }
    }

    public int GetCurrentHealth()
    {
        return currentHealth;
    }

    /// <param name="damage">Amount of damage to apply.</param>
    /// <param name="attacker">Optional: the NetworkObject of the player who dealt damage, for kill credit.</param>
    public void TakeDamage(int damage, NetworkObject attacker = null)
    {
        // TEMP: client-authoritative, will move server-side in networking phase.
        // Only state authority (Server/Host) can modify health
        if (!HasStateAuthority || currentHealth <= 0) return;

        currentHealth -= damage;
        if (currentHealth < 0) currentHealth = 0;

        if (currentHealth <= 0)
        {
            Die(attacker);
        }
    }

    public void ResetHealth()
    {
        if (HasStateAuthority)
        {
            currentHealth = maxHealth;
        }
    }

    void Die(NetworkObject killer)
    {
        OnDeath?.Invoke();

        if (isPlayer)
        {
            // Credit death to this player
            PlayerStats victimStats = GetComponent<PlayerStats>();
            if (victimStats != null) victimStats.AddDeath();

            // Credit kill to the attacker
            if (killer != null)
            {
                PlayerStats killerStats = killer.GetComponent<PlayerStats>();
                PlayerTeamComponent killerTeam = killer.GetComponent<PlayerTeamComponent>();
                PlayerStats victimStatsForFeed = GetComponent<PlayerStats>();
                WeaponController killerWeapon = killer.GetComponent<WeaponController>();

                if (killerStats != null) killerStats.AddKill();

                // Broadcast to kill feed
                if (MatchManager.Instance != null)
                {
                    string killerName = killerStats != null ? killerStats.PlayerName.ToString() : "Unknown";
                    string victimName = victimStatsForFeed != null ? victimStatsForFeed.PlayerName.ToString() : "Unknown";
                    string weaponName = (killerWeapon != null && killerWeapon.currentWeapon != null)
                        ? killerWeapon.currentWeapon.weaponName
                        : "Unknown";
                    MatchManager.Instance.BroadcastKillFeed(killerName, victimName, weaponName);
                }
            }

            if (HasStateAuthority && MatchManager.Instance != null)
            {
                MatchManager.Instance.CheckElimination();
            }
        }
        else
        {
            if (HasStateAuthority)
            {
                Runner.Despawn(Object);
            }
        }
    }
}
