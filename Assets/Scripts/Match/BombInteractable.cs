using UnityEngine;

public class BombInteractable : MonoBehaviour
{
    public float plantDuration = 3.5f;
    public float defuseDuration = 5f;

    private bool isPlanted = false;
    private bool isPlanting = false;
    private bool isDefusing = false;

    private float actionTimer = 0f;
    private Vector3 actionStartPos;

    public BombSite currentSite;
    public PlayerTeamComponent carrier; // Who is holding it
    
    private void OnTriggerEnter(Collider other)
    {
        BombSite site = other.GetComponent<BombSite>();
        if (site != null)
        {
            currentSite = site;
        }
    }

    private void OnTriggerExit(Collider other)
    {
        BombSite site = other.GetComponent<BombSite>();
        if (site != null && currentSite == site)
        {
            currentSite = null;
            CancelAction();
        }
    }

    private void Update()
    {
        if (MatchManager.Instance == null || MatchManager.Instance.currentState != MatchStateType.Live)
            return;

        if (InputManager.Instance != null && InputManager.Instance.isUsing)
        {
            if (!isPlanted && currentSite != null && carrier != null && carrier.team == TeamId.Terrorist)
            {
                // Attempt to plant
                if (!isPlanting)
                {
                    StartAction(true);
                }
                else
                {
                    ProcessAction(true);
                }
            }
            else if (isPlanted)
            {
                // Attempt to defuse
                // Need to find nearby police. For single player slice, assume local player is close if they press Use.
                // In a full game, we'd check distance from player to bomb.
                // Here we just check if carrier (now null or local player) is Police.
                // Since this script is on the bomb, we can just find the local player for now.
                PlayerTeamComponent localPlayer = FindObjectOfType<PlayerTeamComponent>(); 
                if (localPlayer != null && localPlayer.team == TeamId.Police && Vector3.Distance(transform.position, localPlayer.transform.position) < 3f)
                {
                    if (!isDefusing)
                    {
                        StartAction(false);
                    }
                    else
                    {
                        ProcessAction(false);
                    }
                }
            }
        }
        else
        {
            CancelAction();
        }
    }

    private void StartAction(bool planting)
    {
        isPlanting = planting;
        isDefusing = !planting;
        actionTimer = planting ? plantDuration : defuseDuration;
        
        // Find local player to track movement
        PlayerController pc = FindObjectOfType<PlayerController>();
        if (pc != null)
            actionStartPos = pc.transform.position;
    }

    private void ProcessAction(bool planting)
    {
        // Cancel if moved
        PlayerController pc = FindObjectOfType<PlayerController>();
        if (pc != null && Vector3.Distance(actionStartPos, pc.transform.position) > 0.1f)
        {
            CancelAction();
            return;
        }

        actionTimer -= Time.deltaTime;
        // Optionally update some UI progress bar here

        if (actionTimer <= 0)
        {
            if (planting)
            {
                CompletePlant();
            }
            else
            {
                CompleteDefuse();
            }
        }
    }

    private void CancelAction()
    {
        isPlanting = false;
        isDefusing = false;
        actionTimer = 0f;
    }

    private void CompletePlant()
    {
        isPlanted = true;
        isPlanting = false;
        carrier = null; // Detach from player
        transform.SetParent(null); // Leave bomb in world
        
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.PlantBomb();
        }
    }

    private void CompleteDefuse()
    {
        isPlanted = false;
        isDefusing = false;

        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.DefuseBomb();
        }
    }
}
