using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class UIManager : MonoBehaviour
{
    public static UIManager Instance { get; private set; }

    [Header("Player HUD")]
    public Slider healthBar;
    public TextMeshProUGUI ammoText;

    [Header("Match HUD")]
    public TextMeshProUGUI timerText;
    public TextMeshProUGUI scoreText;       // "Police X  -  Y Terrorist"
    public TextMeshProUGUI bombTimerText;   // Shown only when planted
    public TextMeshProUGUI roundNumberText; // "Round 3 / 9"

    [Header("Round End")]
    public GameObject roundEndPanel;
    public TextMeshProUGUI roundEndBannerText;

    [Header("Match End")]
    public GameObject matchEndPanel;
    public TextMeshProUGUI matchEndText;
    public Button matchEndRestartButton; // Only the host should act on this

    [Header("Pause")]
    public GameObject pausePanel;

    // ── Lifecycle ─────────────────────────────────────────────────────────

    private void Awake()
    {
        if (Instance == null) Instance = this;
        else { Destroy(gameObject); return; }
    }

    private void Start()
    {
        SubscribeToMatchManager();
        SubscribeToLocalPlayer();

        if (bombTimerText  != null) bombTimerText.gameObject.SetActive(false);
        if (roundEndPanel  != null) roundEndPanel.SetActive(false);
        if (matchEndPanel  != null) matchEndPanel.SetActive(false);
    }

    private void OnDestroy()
    {
        if (MatchManager.Instance == null) return;
        MatchManager.Instance.OnMatchStateChanged -= HandleMatchStateChanged;
        MatchManager.Instance.OnTimerUpdated      -= UpdateTimerText;
        MatchManager.Instance.OnBombTimerUpdated  -= UpdateBombTimerText;
        MatchManager.Instance.OnRoundEnd          -= ShowRoundEndBanner;
        MatchManager.Instance.OnMatchEnd          -= ShowMatchEndScreen;
    }

    // ── Subscriptions ─────────────────────────────────────────────────────

    private void SubscribeToMatchManager()
    {
        if (MatchManager.Instance == null) return;
        MatchManager.Instance.OnMatchStateChanged += HandleMatchStateChanged;
        MatchManager.Instance.OnTimerUpdated      += UpdateTimerText;
        MatchManager.Instance.OnBombTimerUpdated  += UpdateBombTimerText;
        MatchManager.Instance.OnRoundEnd          += ShowRoundEndBanner;
        MatchManager.Instance.OnMatchEnd          += ShowMatchEndScreen;
    }

    private void SubscribeToLocalPlayer()
    {
        // Find local player and subscribe to their Health / Weapon events
        PlayerController localPlayer = FindObjectOfType<PlayerController>();
        if (localPlayer == null) return;

        Health h = localPlayer.GetComponent<Health>();
        if (h != null) h.OnHealthChanged += UpdateHealth;

        WeaponController wc = localPlayer.GetComponent<WeaponController>();
        if (wc != null) wc.OnAmmoChanged += UpdateAmmoText;
    }

    // ── Match State ───────────────────────────────────────────────────────

    private void HandleMatchStateChanged(MatchStateType state)
    {
        switch (state)
        {
            case MatchStateType.Live:
                if (roundEndPanel != null) roundEndPanel.SetActive(false);
                if (bombTimerText != null) bombTimerText.gameObject.SetActive(false);
                UpdateScoreAndRound();
                break;

            case MatchStateType.FreezeTime:
                if (roundEndPanel != null) roundEndPanel.SetActive(false);
                if (bombTimerText != null) bombTimerText.gameObject.SetActive(false);
                UpdateScoreAndRound();
                break;
        }
    }

    private void UpdateScoreAndRound()
    {
        if (MatchManager.Instance == null) return;

        if (scoreText != null)
            scoreText.text = $"Police  {MatchManager.Instance.policeScore}  —  {MatchManager.Instance.terroristScore}  Terrorist";

        if (roundNumberText != null)
        {
            int total = MatchManager.Instance.policeScore + MatchManager.Instance.terroristScore;
            roundNumberText.text = $"Round {total + 1}";
        }
    }

    // ── HUD Updates ───────────────────────────────────────────────────────

    public void UpdateHealth(int currentHealth, int maxHealth)
    {
        if (healthBar != null)
        {
            healthBar.maxValue = maxHealth;
            healthBar.value = currentHealth;
        }
    }

    public void UpdateAmmoText(int currentAmmo, int maxAmmo)
    {
        if (ammoText != null)
            ammoText.text = $"{currentAmmo}  /  {maxAmmo}";
    }

    private void UpdateTimerText(float time)
    {
        if (timerText != null)
        {
            int s = Mathf.CeilToInt(time);
            timerText.text = $"{s / 60:00}:{s % 60:00}";
        }
    }

    private void UpdateBombTimerText(float time)
    {
        if (bombTimerText != null)
        {
            bombTimerText.gameObject.SetActive(true);
            bombTimerText.text = $"BOMB  {Mathf.CeilToInt(time)}s";
        }
    }

    // ── Round End ─────────────────────────────────────────────────────────

    private void ShowRoundEndBanner(TeamId winner, RoundEndReason reason)
    {
        if (roundEndPanel != null) roundEndPanel.SetActive(true);
        if (bombTimerText != null) bombTimerText.gameObject.SetActive(false);

        if (roundEndBannerText != null)
        {
            string winnerStr = winner switch
            {
                TeamId.Police    => "Police Win",
                TeamId.Terrorist => "Terrorists Win",
                _                => "Draw"
            };
            string reasonStr = reason switch
            {
                RoundEndReason.Elimination => "Elimination",
                RoundEndReason.BombExploded => "Bomb Exploded",
                RoundEndReason.BombDefused  => "Bomb Defused",
                RoundEndReason.TimeExpired  => "Time Expired",
                _                           => ""
            };
            roundEndBannerText.text = $"{winnerStr}\n<size=75%>{reasonStr}</size>";
        }

        UpdateScoreAndRound();
    }

    // ── Match End ─────────────────────────────────────────────────────────

    private void ShowMatchEndScreen(TeamId winner)
    {
        if (matchEndPanel != null) matchEndPanel.SetActive(true);
        if (roundEndPanel != null) roundEndPanel.SetActive(false);

        if (matchEndText != null && MatchManager.Instance != null)
        {
            string winnerStr = winner == TeamId.Police ? "POLICE WIN THE MATCH!" : "TERRORISTS WIN THE MATCH!";
            matchEndText.text = $"{winnerStr}\n\nFinal Score\nPolice  {MatchManager.Instance.policeScore}  —  {MatchManager.Instance.terroristScore}  Terrorist";
        }
    }

    // ── Pause ─────────────────────────────────────────────────────────────

    public void TogglePauseMenu(bool isPaused)
    {
        if (pausePanel != null) pausePanel.SetActive(isPaused);
    }
}
