using Fusion;
using UnityEngine;

/// <summary>
/// Tracks per-player match statistics. Lives on the Player NetworkObject.
/// All fields are [Networked] so all clients can read them for the scoreboard.
/// </summary>
public class PlayerStats : NetworkBehaviour
{
    [Networked] public NetworkString<_32> PlayerName { get; set; }
    [Networked] public int Kills { get; set; }
    [Networked] public int Deaths { get; set; }
    [Networked] public TeamId Team { get; set; }

    public override void Spawned()
    {
        if (HasInputAuthority)
        {
            // Set name from local system; in production this would come from a lobby/profile
            Rpc_SetName(SystemInfo.deviceName.Length > 0 ? SystemInfo.deviceName : "Player");
        }

        // Sync team from PlayerTeamComponent if present
        PlayerTeamComponent teamComp = GetComponent<PlayerTeamComponent>();
        if (teamComp != null && HasStateAuthority)
        {
            Team = teamComp.team;
        }
    }

    [Rpc(RpcSources.InputAuthority, RpcTargets.StateAuthority)]
    private void Rpc_SetName(string name)
    {
        PlayerName = name;
    }

    /// <summary>Called by the server when this player gets a kill.</summary>
    public void AddKill()
    {
        if (HasStateAuthority) Kills++;
    }

    /// <summary>Called by the server when this player dies.</summary>
    public void AddDeath()
    {
        if (HasStateAuthority) Deaths++;
    }

    /// <summary>Resets K/D for a new match (not a new round).</summary>
    public void ResetStats()
    {
        if (HasStateAuthority)
        {
            Kills = 0;
            Deaths = 0;
        }
    }
}
