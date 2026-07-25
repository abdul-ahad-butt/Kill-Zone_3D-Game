using UnityEngine;
using UnityEngine.InputSystem;

public class InputManager : MonoBehaviour
{
    public static InputManager Instance { get; private set; }

    [Header("Input Values")]
    public Vector2 moveInput;
    public Vector2 lookInput;
    public bool isJumping;
    public bool isFiring;
    public bool isUsing;
    public bool isScoreboardOpen;

    private void Awake()
    {
        if (Instance == null)
            Instance = this;
        else
            Destroy(gameObject);
    }

    public void OnMove(InputValue value)    => moveInput = value.Get<Vector2>();
    public void OnLook(InputValue value)    => lookInput = value.Get<Vector2>();

    public void OnJump(InputValue value)    => isJumping = value.isPressed;
    public void OnFire(InputValue value)    => isFiring = value.isPressed;
    public void OnUse(InputValue value)     => isUsing = value.isPressed;

    /// <summary>Tab — hold to view scoreboard.</summary>
    public void OnScoreboard(InputValue value) => isScoreboardOpen = value.isPressed;
}
