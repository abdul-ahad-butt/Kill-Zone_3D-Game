using Fusion;
using System;
using System.Collections.Generic;
using UnityEngine;

public class MatchManager : NetworkBehaviour
{
    public static MatchManager Instance { get; private set; }

    [Header("Match Settings")]
    public float warmUpDuration = 10f;
    public float freezeTimeDuration = 10f;
    public float roundLiveDuration = 120f;
    public float roundEndDuration = 5f;
    public int roundsToWin = 5;   // First to 5 wins (best of 9)
    public int halfTimeRound = 5; // Swap sides after this many total rounds

    [Header("Bomb Settings")]
    public float bombTimerDuration = 40f;

    [Networked] public bool isBombPlanted { get; set; }
    [Networked] public float currentBombTimer { get; set; }
    [Networked] public int policeScore { get; set; }
    [Networked] public int terroristScore { get; set; }
    [Networked] public MatchStateType currentState { get; set; }
    [Networked] public float stateTimer { get; set; }
    [Networked] public int roundNumber { get; set; }

    private MatchState stateHandler;
    private Dictionary<MatchStateType, MatchState> states;

    public List<PlayerTeamComponent> allPlayers = new List<PlayerTeamComponent>();

    // ── Events (raised via RPC so all clients fire them) ──────────────────
    public event Action<MatchStateType> OnMatchStateChanged;
    public event Action OnRoundStart;
    public event Action<TeamId, RoundEndReason> OnRoundEnd;
    public event Action<TeamId> OnMatchEnd;
    public event Action<float> OnTimerUpdated;
    public event Action<float> OnBombTimerUpdated;
    public event Action<string, string, string> OnKillFeedEvent; // killer, victim, weapon

    private ChangeDetector _changeDetector;

    private void Awake()
    {
        if (Instance == null)
            Instance = this;
        else
            Destroy(gameObject);
    }

    public override void Spawned()
    {
        _changeDetector = GetChangeDetector(ChangeDetector.Source.SimulationState);

        states = new Dictionary<MatchStateType, MatchState>
        {
            { MatchStateType.WarmUp,    new WarmUpState(this)    },
            { MatchStateType.FreezeTime,new FreezeTimeState(this)},
            { MatchStateType.Live,      new LiveState(this)      },
            { MatchStateType.RoundEnd,  new RoundEndState(this)  },
            { MatchStateType.MatchEnd,  new MatchEndState(this)  }
        };

        if (HasStateAuthority)
        {
            roundNumber = 0;
            ChangeState(MatchStateType.WarmUp);
        }
    }

    public override void Render()
    {
        foreach (var change in _changeDetector.DetectChanges(this))
        {
            switch (change)
            {
                case nameof(currentState):    OnMatchStateChanged?.Invoke(currentState); break;
                case nameof(stateTimer):      OnTimerUpdated?.Invoke(stateTimer);        break;
                case nameof(currentBombTimer):OnBombTimerUpdated?.Invoke(currentBombTimer); break;
            }
        }
    }

    public override void FixedUpdateNetwork()
    {
        if (!HasStateAuthority) return;
        stateHandler?.Update();
    }

    // ── State Machine ──────────────────────────────────────────────────────

    public void ChangeState(MatchStateType newState)
    {
        if (!HasStateAuthority) return;
        stateHandler?.Exit();
        currentState = newState;
        stateHandler = states[newState];
        stateHandler.Enter();
        OnMatchStateChanged?.Invoke(newState); // local (Host) notification
    }

    // ── Round Advance (called by RoundEndState) ────────────────────────────

    /// <summary>
    /// Called by RoundEndState after the post-round delay expires.
    /// Handles half-time swap and match-end detection.
    /// </summary>
    public void AdvanceRound()
    {
        if (!HasStateAuthority) return;

        // Half-time side swap
        if (roundNumber == halfTimeRound)
        {
            SpawnManager spawnMgr = FindObjectOfType<SpawnManager>();
            if (spawnMgr != null) spawnMgr.SwapSides();
        }

        // Check if either team has won the match
        if (policeScore >= roundsToWin)
        {
            Rpc_TriggerMatchEnd(TeamId.Police);
            ChangeState(MatchStateType.MatchEnd);
            return;
        }
        if (terroristScore >= roundsToWin)
        {
            Rpc_TriggerMatchEnd(TeamId.Terrorist);
            ChangeState(MatchStateType.MatchEnd);
            return;
        }

        ChangeState(MatchStateType.FreezeTime);
    }

    // ── Player Registry ───────────────────────────────────────────────────

    public void RegisterPlayer(PlayerTeamComponent player)
    {
        if (!allPlayers.Contains(player)) allPlayers.Add(player);
    }

    public void UnregisterPlayer(PlayerTeamComponent player)
    {
        allPlayers.Remove(player);
    }

    // ── Bomb ──────────────────────────────────────────────────────────────

    public void PlantBomb()
    {
        if (!HasStateAuthority || currentState != MatchStateType.Live) return;
        isBombPlanted = true;
        currentBombTimer = bombTimerDuration;
    }

    public void DefuseBomb()
    {
        if (!HasStateAuthority || currentState != MatchStateType.Live || !isBombPlanted) return;
        isBombPlanted = false;
        TriggerRoundEnd(TeamId.Police, RoundEndReason.BombDefused);
    }

    // ── Round / Elimination ───────────────────────────────────────────────

    public void TriggerRoundEnd(TeamId winner, RoundEndReason reason)
    {
        if (!HasStateAuthority) return;

        if (winner == TeamId.Police)       policeScore++;
        else if (winner == TeamId.Terrorist) terroristScore++;

        roundNumber++;
        Rpc_TriggerRoundEnd(winner, reason);
        ChangeState(MatchStateType.RoundEnd);
    }

    public void TriggerRoundStart()
    {
        Rpc_TriggerRoundStart();
    }

    public void CheckElimination()
    {
        if (!HasStateAuthority || currentState != MatchStateType.Live) return;

        bool policeAlive = false;
        bool terroristAlive = false;

        foreach (var player in allPlayers)
        {
            Health health = player.GetComponent<Health>();
            if (health != null && health.GetCurrentHealth() > 0)
            {
                if (player.team == TeamId.Police)    policeAlive = true;
                if (player.team == TeamId.Terrorist) terroristAlive = true;
            }
        }

        if (!policeAlive && terroristAlive)
            TriggerRoundEnd(TeamId.Terrorist, RoundEndReason.Elimination);
        else if (policeAlive && !terroristAlive && !isBombPlanted)
            TriggerRoundEnd(TeamId.Police, RoundEndReason.Elimination);
        else if (!policeAlive && !terroristAlive)
            TriggerRoundEnd(TeamId.None, RoundEndReason.Elimination);
    }

    // ── Kill Feed ─────────────────────────────────────────────────────────

    public void BroadcastKillFeed(string killerName, string victimName, string weaponName)
    {
        if (!HasStateAuthority) return;
        Rpc_KillFeed(killerName, victimName, weaponName);
    }

    // ── Timer helpers (called by state classes) ───────────────────────────

    public void UpdateTimerUI(float time)   => OnTimerUpdated?.Invoke(time);
    public void UpdateBombTimerUI(float time) => OnBombTimerUpdated?.Invoke(time);

    // ── RPCs ──────────────────────────────────────────────────────────────

    [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
    private void Rpc_TriggerRoundStart() => OnRoundStart?.Invoke();

    [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
    private void Rpc_TriggerRoundEnd(TeamId winner, RoundEndReason reason) => OnRoundEnd?.Invoke(winner, reason);

    [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
    private void Rpc_TriggerMatchEnd(TeamId winner) => OnMatchEnd?.Invoke(winner);

    [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
    private void Rpc_KillFeed(string killer, string victim, string weapon) =>
        OnKillFeedEvent?.Invoke(killer, victim, weapon);
}
