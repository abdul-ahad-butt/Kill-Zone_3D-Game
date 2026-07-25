using UnityEngine;
using UnityEngine.UI;

public class LoadoutUI : MonoBehaviour
{
    [Header("Panel")]
    public GameObject loadoutPanel;
    public Button rifleButton;
    public Button smgButton;

    [Header("References — set to local player at runtime")]
    public PlayerTeamComponent localPlayerTeam;
    public WeaponController localPlayerWeaponController;

    [Header("Weapon Definitions")]
    public WeaponDefinition rifleDef;
    public WeaponDefinition smgDef;
    public WeaponDefinition pistolDef; // secondary — not yet equipped here, reserved for Phase 3+

    private bool _playerHasChosen = false;

    private void Start()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnMatchStateChanged += HandleMatchStateChanged;
            MatchManager.Instance.OnRoundStart        += HandleRoundStart;
        }

        if (rifleButton != null) rifleButton.onClick.AddListener(SelectRifle);
        if (smgButton   != null) smgButton.onClick.AddListener(SelectSMG);
    }

    private void OnDestroy()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnMatchStateChanged -= HandleMatchStateChanged;
            MatchManager.Instance.OnRoundStart        -= HandleRoundStart;
        }
    }

    // ── State reactions ───────────────────────────────────────────────────

    private void HandleRoundStart()
    {
        // Reset choice flag each round
        _playerHasChosen = false;
    }

    private void HandleMatchStateChanged(MatchStateType state)
    {
        if (state == MatchStateType.FreezeTime)
        {
            ShowLoadout();
        }
        else if (state == MatchStateType.Live)
        {
            // If player didn't choose during FreezeTime, auto-equip
            if (!_playerHasChosen) AutoEquipDefault();
            HideLoadout();
        }
        else
        {
            HideLoadout();
        }
    }

    // ── Display ───────────────────────────────────────────────────────────

    public void ShowLoadout()
    {
        if (loadoutPanel == null || localPlayerTeam == null) return;
        loadoutPanel.SetActive(true);

        bool isTerrorist = localPlayerTeam.team == TeamId.Terrorist;
        // Police: only rifle option. Terrorists: rifle or SMG.
        if (smgButton   != null) smgButton.gameObject.SetActive(isTerrorist);
        if (rifleButton != null) rifleButton.gameObject.SetActive(true);
    }

    public void HideLoadout()
    {
        if (loadoutPanel != null) loadoutPanel.SetActive(false);
    }

    // ── Selections ────────────────────────────────────────────────────────

    private void SelectRifle()
    {
        Equip(rifleDef);
    }

    private void SelectSMG()
    {
        Equip(smgDef);
    }

    private void Equip(WeaponDefinition def)
    {
        if (localPlayerWeaponController != null && def != null)
        {
            localPlayerWeaponController.EquipWeapon(def);
            _playerHasChosen = true;
        }
        HideLoadout();
    }

    /// <summary>Equips team default if the player didn't choose during FreezeTime.</summary>
    private void AutoEquipDefault()
    {
        if (localPlayerTeam == null || localPlayerWeaponController == null) return;

        WeaponDefinition defaultWeapon = (localPlayerTeam.team == TeamId.Terrorist) ? smgDef : rifleDef;
        if (defaultWeapon != null)
            localPlayerWeaponController.EquipWeapon(defaultWeapon);
    }
}
