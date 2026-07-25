using Fusion;

public enum MatchStateType
{
    WarmUp,
    FreezeTime,
    Live,
    RoundEnd,
    MatchEnd
}

public abstract class MatchState
{
    protected MatchManager matchManager;

    public MatchState(MatchManager manager)
    {
        this.matchManager = manager;
    }

    public abstract void Enter();
    public abstract void Update();
    public abstract void Exit();
}

public class WarmUpState : MatchState
{
    public WarmUpState(MatchManager manager) : base(manager) { }

    public override void Enter()
    {
        matchManager.stateTimer = matchManager.warmUpDuration;
    }

    public override void Update()
    {
        matchManager.stateTimer -= matchManager.Runner.DeltaTime;
        if (matchManager.stateTimer <= 0)
            matchManager.ChangeState(MatchStateType.FreezeTime);
    }

    public override void Exit() { }
}

public class FreezeTimeState : MatchState
{
    public FreezeTimeState(MatchManager manager) : base(manager) { }

    public override void Enter()
    {
        matchManager.stateTimer = matchManager.freezeTimeDuration;
        matchManager.isBombPlanted = false;
        matchManager.currentBombTimer = 0f;
        matchManager.TriggerRoundStart();
    }

    public override void Update()
    {
        matchManager.stateTimer -= matchManager.Runner.DeltaTime;
        if (matchManager.stateTimer <= 0)
            matchManager.ChangeState(MatchStateType.Live);
    }

    public override void Exit() { }
}

public class LiveState : MatchState
{
    public LiveState(MatchManager manager) : base(manager) { }

    public override void Enter()
    {
        matchManager.stateTimer = matchManager.roundLiveDuration;
    }

    public override void Update()
    {
        if (matchManager.isBombPlanted)
        {
            matchManager.currentBombTimer -= matchManager.Runner.DeltaTime;
            if (matchManager.currentBombTimer <= 0)
                matchManager.TriggerRoundEnd(TeamId.Terrorist, RoundEndReason.BombExploded);
        }
        else
        {
            matchManager.stateTimer -= matchManager.Runner.DeltaTime;
            if (matchManager.stateTimer <= 0)
                matchManager.TriggerRoundEnd(TeamId.Police, RoundEndReason.TimeExpired);
        }
    }

    public override void Exit() { }
}

public class RoundEndState : MatchState
{
    public RoundEndState(MatchManager manager) : base(manager) { }

    public override void Enter()
    {
        matchManager.stateTimer = matchManager.roundEndDuration;
    }

    public override void Update()
    {
        matchManager.stateTimer -= matchManager.Runner.DeltaTime;
        if (matchManager.stateTimer <= 0)
        {
            // Delegate to MatchManager which handles best-of-9 and side-swap logic
            matchManager.AdvanceRound();
        }
    }

    public override void Exit() { }
}

public class MatchEndState : MatchState
{
    public MatchEndState(MatchManager manager) : base(manager) { }
    public override void Enter() { }
    public override void Update() { }
    public override void Exit() { }
}
