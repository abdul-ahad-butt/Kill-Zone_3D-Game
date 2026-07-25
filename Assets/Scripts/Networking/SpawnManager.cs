using Fusion;
using System.Collections.Generic;
using UnityEngine;

public class SpawnManager : NetworkBehaviour, IPlayerJoined, IPlayerLeft
{
    [Header("Prefab & Spawns")]
    public NetworkPrefabRef playerPrefab;
    public Transform[] policeSpawns;
    public Transform[] terroristSpawns;

    [Header("Team Limits")]
    public int maxPlayersPerTeam = 5;

    private Dictionary<PlayerRef, NetworkObject> spawnedCharacters = new Dictionary<PlayerRef, NetworkObject>();

    public override void Spawned()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnRoundStart += HandleRoundStart;
        }
    }

    public override void Despawned(NetworkRunner runner, bool hasState)
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnRoundStart -= HandleRoundStart;
        }
    }

    public void PlayerJoined(PlayerRef player)
    {
        if (!HasStateAuthority) return;

        Vector3 spawnPos = Vector3.up * 2f;
        NetworkObject networkPlayerObject = Runner.Spawn(playerPrefab, spawnPos, Quaternion.identity, player);
        spawnedCharacters.Add(player, networkPlayerObject);

        // Auto-balance: assign team based on current counts
        TeamId assignedTeam = GetAutoBalancedTeam();

        PlayerTeamComponent teamComp = networkPlayerObject.GetComponent<PlayerTeamComponent>();
        if (teamComp != null)
        {
            teamComp.team = assignedTeam;
        }

        // Sync team to PlayerStats
        PlayerStats stats = networkPlayerObject.GetComponent<PlayerStats>();
        if (stats != null)
        {
            stats.Team = assignedTeam;
        }

        Debug.Log($"Player {player.PlayerId} joined as {assignedTeam}");
    }

    public void PlayerLeft(PlayerRef player)
    {
        if (!HasStateAuthority) return;

        if (spawnedCharacters.TryGetValue(player, out NetworkObject networkObject))
        {
            Runner.Despawn(networkObject);
            spawnedCharacters.Remove(player);
        }
    }

    /// <summary>
    /// Returns the correct team for a new joiner.
    /// Police fills to maxPlayersPerTeam first, then Terrorist, then None (spectator).
    /// </summary>
    private TeamId GetAutoBalancedTeam()
    {
        int policeCount = GetTeamCount(TeamId.Police);
        int terroristCount = GetTeamCount(TeamId.Terrorist);

        if (policeCount <= terroristCount && policeCount < maxPlayersPerTeam)
            return TeamId.Police;
        if (terroristCount < maxPlayersPerTeam)
            return TeamId.Terrorist;

        Debug.LogWarning("Both teams are full — assigning spectator.");
        return TeamId.None; // Spectator slot
    }

    public int GetTeamCount(TeamId team)
    {
        int count = 0;
        foreach (var kvp in spawnedCharacters)
        {
            PlayerTeamComponent tc = kvp.Value.GetComponent<PlayerTeamComponent>();
            if (tc != null && tc.team == team) count++;
        }
        return count;
    }

    /// <summary>Swaps every player's team (Police <-> Terrorist) for half-time.</summary>
    public void SwapSides()
    {
        if (!HasStateAuthority) return;

        foreach (var kvp in spawnedCharacters)
        {
            PlayerTeamComponent tc = kvp.Value.GetComponent<PlayerTeamComponent>();
            PlayerStats stats = kvp.Value.GetComponent<PlayerStats>();
            if (tc == null) continue;

            if (tc.team == TeamId.Police)
            {
                tc.team = TeamId.Terrorist;
            }
            else if (tc.team == TeamId.Terrorist)
            {
                tc.team = TeamId.Police;
            }

            if (stats != null) stats.Team = tc.team;
        }

        Debug.Log("Half-time: sides swapped.");
    }

    private void HandleRoundStart()
    {
        if (!HasStateAuthority) return;

        int policeIndex = 0;
        int terroristIndex = 0;

        foreach (var kvp in spawnedCharacters)
        {
            NetworkObject obj = kvp.Value;
            PlayerTeamComponent teamComp = obj.GetComponent<PlayerTeamComponent>();
            if (teamComp == null) continue;

            Transform spawnPoint = null;
            if (teamComp.team == TeamId.Police && policeSpawns != null && policeSpawns.Length > 0)
            {
                spawnPoint = policeSpawns[policeIndex % policeSpawns.Length];
                policeIndex++;
            }
            else if (teamComp.team == TeamId.Terrorist && terroristSpawns != null && terroristSpawns.Length > 0)
            {
                spawnPoint = terroristSpawns[terroristIndex % terroristSpawns.Length];
                terroristIndex++;
            }

            if (spawnPoint != null)
            {
                CharacterController cc = obj.GetComponent<CharacterController>();
                if (cc != null) cc.enabled = false;
                obj.transform.position = spawnPoint.position;
                obj.transform.rotation = spawnPoint.rotation;
                if (cc != null) cc.enabled = true;
            }

            // Reset health each round
            Health health = obj.GetComponent<Health>();
            if (health != null) health.ResetHealth();
        }
    }
}
