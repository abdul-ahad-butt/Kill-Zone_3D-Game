using UnityEngine;
using UnityEngine.SceneManagement;

public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    private int score = 0;
    private bool isGameOver = false;
    private bool isPaused = false;

    private void Awake()
    {
        if (Instance == null)
            Instance = this;
        else
            Destroy(gameObject);
    }

    private void Start()
    {
        if (UIManager.Instance != null)
        {
            UIManager.Instance.UpdateScoreText(score);
            UIManager.Instance.TogglePauseMenu(false);
            if (UIManager.Instance.gameOverPanel != null)
                UIManager.Instance.gameOverPanel.SetActive(false);
        }
        Time.timeScale = 1f;
    }

    public void AddScore(int points)
    {
        if (isGameOver) return;
        score += points;
        if (UIManager.Instance != null)
        {
            UIManager.Instance.UpdateScoreText(score);
        }
    }

    public void GameOver()
    {
        isGameOver = true;
        if (UIManager.Instance != null)
        {
            UIManager.Instance.ShowGameOver();
        }
        Time.timeScale = 0f; // Pause game logic
    }

    public void TogglePause()
    {
        if (isGameOver) return;

        isPaused = !isPaused;
        Time.timeScale = isPaused ? 0f : 1f;

        if (UIManager.Instance != null)
        {
            UIManager.Instance.TogglePauseMenu(isPaused);
        }
    }

    // Called from UI Button
    public void RestartGame()
    {
        Time.timeScale = 1f;
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
    }

    // Called from UI Button
    public void QuitGame()
    {
#if !UNITY_WEBGL
        Application.Quit();
#else
        // Application.Quit() has no effect on WebGL.
        // Optionally redirect to a landing page:
        // Application.OpenURL("https://yourgame.com");
        Debug.Log("[GameManager] QuitGame called — no-op on WebGL.");
#endif
    }
}
