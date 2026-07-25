using UnityEngine;

public class PlayerTeamComponent : MonoBehaviour
{
    public TeamId team = TeamId.None;

    private void Start()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.RegisterPlayer(this);
        }
    }

    private void OnDestroy()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.UnregisterPlayer(this);
        }
    }
}
