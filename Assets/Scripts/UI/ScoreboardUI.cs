using Fusion;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// Hold Tab to show. Two columns: Police | Terrorist.
/// Reads PlayerStats from all active NetworkObjects each frame the panel is visible.
/// </summary>
public class ScoreboardUI : MonoBehaviour
{
    [Header("Panel Root")]
    public GameObject scoreboardPanel;

    [Header("Column Containers")]
    public Transform policeListParent;
    public Transform terroristListParent;

    [Header("Row Prefab (Police & Terrorist)")]
    public GameObject scoreboardRowPrefab; // TextMeshProUGUI with format: "Name   K   D"

    [Header("Header Texts")]
    public TextMeshProUGUI policeHeaderText;
    public TextMeshProUGUI terroristHeaderText;

    private NetworkRunner _runner;

    private void Start()
    {
        if (scoreboardPanel != null)
            scoreboardPanel.SetActive(false);

        // Find NetworkRunner in the scene
        _runner = FindObjectOfType<NetworkRunner>();
    }

    private void Update()
    {
        bool show = InputManager.Instance != null && InputManager.Instance.isScoreboardOpen;

        if (scoreboardPanel != null && scoreboardPanel.activeSelf != show)
        {
            scoreboardPanel.SetActive(show);
        }

        if (show) RefreshRows();
    }

    private void RefreshRows()
    {
        // Clear existing rows
        foreach (Transform child in policeListParent)   Destroy(child.gameObject);
        foreach (Transform child in terroristListParent) Destroy(child.gameObject);

        if (_runner == null) return;

        // Gather all PlayerStats across all active NetworkObjects
        List<PlayerStats> policeStats    = new List<PlayerStats>();
        List<PlayerStats> terroristStats = new List<PlayerStats>();

        foreach (var obj in _runner.GetAllObjects())
        {
            PlayerStats ps = obj.GetComponent<PlayerStats>();
            if (ps == null) continue;

            if (ps.Team == TeamId.Police)       policeStats.Add(ps);
            else if (ps.Team == TeamId.Terrorist) terroristStats.Add(ps);
        }

        // Sort by kills descending
        policeStats.Sort((a, b) => b.Kills.CompareTo(a.Kills));
        terroristStats.Sort((a, b) => b.Kills.CompareTo(a.Kills));

        BuildRows(policeStats,    policeListParent);
        BuildRows(terroristStats, terroristListParent);

        if (policeHeaderText != null)
            policeHeaderText.text = $"POLICE  ({(MatchManager.Instance != null ? MatchManager.Instance.policeScore : 0)} wins)";
        if (terroristHeaderText != null)
            terroristHeaderText.text = $"TERRORIST  ({(MatchManager.Instance != null ? MatchManager.Instance.terroristScore : 0)} wins)";
    }

    private void BuildRows(List<PlayerStats> statsList, Transform parent)
    {
        foreach (var ps in statsList)
        {
            if (scoreboardRowPrefab == null) continue;

            GameObject row = Instantiate(scoreboardRowPrefab, parent);
            TextMeshProUGUI label = row.GetComponent<TextMeshProUGUI>();
            if (label != null)
            {
                label.text = $"{ps.PlayerName,-20}  {ps.Kills,3} / {ps.Deaths,-3}";
            }
        }
    }
}
