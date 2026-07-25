using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;

/// <summary>
/// Displays the last N kill events as auto-expiring text entries.
/// Listens to MatchManager.OnKillFeedEvent (broadcast to all clients via RPC).
/// </summary>
public class KillFeedUI : MonoBehaviour
{
    [Header("Settings")]
    public int maxEntries = 4;
    public float entryLifetime = 5f;

    [Header("References")]
    public Transform entryParent;   // Vertical layout group
    public GameObject entryPrefab;  // A simple TMP label prefab

    private Queue<GameObject> activeEntries = new Queue<GameObject>();

    private void Start()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnKillFeedEvent += HandleKillEvent;
        }
    }

    private void OnDestroy()
    {
        if (MatchManager.Instance != null)
        {
            MatchManager.Instance.OnKillFeedEvent -= HandleKillEvent;
        }
    }

    private void HandleKillEvent(string killer, string victim, string weapon)
    {
        // Enforce max entries cap
        while (activeEntries.Count >= maxEntries)
        {
            GameObject oldest = activeEntries.Dequeue();
            if (oldest != null) Destroy(oldest);
        }

        if (entryPrefab == null || entryParent == null) return;

        GameObject entry = Instantiate(entryPrefab, entryParent);
        TextMeshProUGUI label = entry.GetComponent<TextMeshProUGUI>();
        if (label != null)
        {
            label.text = $"<b>{killer}</b>  killed  <b>{victim}</b>  <size=75%>({weapon})</size>";
        }

        activeEntries.Enqueue(entry);
        StartCoroutine(ExpireEntry(entry, entryLifetime));
    }

    private IEnumerator ExpireEntry(GameObject entry, float delay)
    {
        yield return new WaitForSeconds(delay);

        if (entry != null)
        {
            // Remove from queue safely
            // (Queue doesn't support random remove, so just destroy; it'll be null-checked on dequeue)
            Destroy(entry);
        }
    }
}
