using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem.EnhancedTouch;
using Touch = UnityEngine.InputSystem.EnhancedTouch.Touch;

/// <summary>
/// Translates touch input into the same InputManager fields used by desktop input.
/// Additive: disables itself on non-mobile platforms so keyboard/mouse keeps working.
///
/// Layout (portrait or landscape):
///   Left  half  → virtual joystick  → InputManager.moveInput
///   Right half  → drag-to-look     → InputManager.lookInput
///   Fire  button region (bottom-right corner)  → InputManager.isFiring
///   Use   button region (above fire)           → InputManager.isUsing
///   Reload button region (above use)           → InputManager.isJumping (reused for now)
/// </summary>
[DefaultExecutionOrder(-5)] // Run before PlayerController reads InputManager
public class TouchInputLayer : MonoBehaviour
{
    [Header("Look Sensitivity")]
    public float lookSensitivity = 0.15f;

    [Header("Button Regions (normalized screen coords 0-1)")]
    public Rect fireButtonRect   = new Rect(0.80f, 0.05f, 0.18f, 0.15f);
    public Rect useButtonRect    = new Rect(0.80f, 0.22f, 0.18f, 0.12f);
    public Rect reloadButtonRect = new Rect(0.80f, 0.36f, 0.18f, 0.12f);

    [Header("Virtual Joystick")]
    public VirtualJoystickUI joystickUI; // Optional visual overlay

    // Internal state
    private int _moveTouchId  = -1;
    private int _lookTouchId  = -1;
    private Vector2 _joystickOrigin;
    private Vector2 _joystickCurrent;
    private const float JoystickDeadRadius = 10f;
    private const float JoystickMaxRadius  = 80f;

    private void Awake()
    {
        // Kill this component entirely on non-mobile so it is zero-overhead on PC/Editor
        if (!Application.isMobilePlatform)
        {
            enabled = false;
            if (joystickUI != null) joystickUI.gameObject.SetActive(false);
            return;
        }

        EnhancedTouchSupport.Enable();
    }

    private void OnDestroy()
    {
        if (Application.isMobilePlatform)
            EnhancedTouchSupport.Disable();
    }

    private void Update()
    {
        if (InputManager.Instance == null) return;

        // Reset every frame — buttons are held-state
        InputManager.Instance.isFiring   = false;
        InputManager.Instance.isUsing    = false;
        InputManager.Instance.lookInput  = Vector2.zero;

        var touches = Touch.activeTouches;

        foreach (var touch in touches)
        {
            Vector2 screenPos = touch.screenPosition;
            float normX = screenPos.x / Screen.width;
            float normY = screenPos.y / Screen.height;

            // ── Movement (left half) ──────────────────────────────────────
            if (normX < 0.5f)
            {
                HandleJoystick(touch, screenPos);
                continue;
            }

            // ── Buttons (right side, specific rects) ─────────────────────
            if (IsInRect(normX, normY, fireButtonRect))
            {
                InputManager.Instance.isFiring = true;
                continue;
            }
            if (IsInRect(normX, normY, useButtonRect))
            {
                InputManager.Instance.isUsing = true;
                continue;
            }
            if (IsInRect(normX, normY, reloadButtonRect))
            {
                // Reuse isJumping as a reload signal for now; bind to a dedicated
                // InputManager.isReloading bool in a later cleanup pass if desired.
                InputManager.Instance.isJumping = touch.phase == UnityEngine.InputSystem.TouchPhase.Began;
                continue;
            }

            // ── Look (right half, not a button) ──────────────────────────
            HandleLook(touch);
        }

        // Clear joystick if no left-half touch
        bool hasLeftTouch = false;
        foreach (var touch in touches)
        {
            if (touch.screenPosition.x / Screen.width < 0.5f) { hasLeftTouch = true; break; }
        }
        if (!hasLeftTouch)
        {
            _moveTouchId = -1;
            InputManager.Instance.moveInput = Vector2.zero;
            if (joystickUI != null) joystickUI.SetThumbPosition(Vector2.zero, Vector2.zero);
        }
    }

    // ── Joystick ──────────────────────────────────────────────────────────

    private void HandleJoystick(Touch touch, Vector2 screenPos)
    {
        if (touch.phase == UnityEngine.InputSystem.TouchPhase.Began)
        {
            _moveTouchId   = touch.touchId;
            _joystickOrigin = screenPos;
            _joystickCurrent = screenPos;
        }

        if (touch.touchId != _moveTouchId) return;

        _joystickCurrent = screenPos;
        Vector2 delta = _joystickCurrent - _joystickOrigin;

        float dist = delta.magnitude;
        Vector2 dir = dist > JoystickDeadRadius ? delta / dist : Vector2.zero;
        float magnitude = Mathf.Clamp01((dist - JoystickDeadRadius) / (JoystickMaxRadius - JoystickDeadRadius));

        InputManager.Instance.moveInput = dir * magnitude;

        if (joystickUI != null)
            joystickUI.SetThumbPosition(_joystickOrigin, delta);
    }

    // ── Look ──────────────────────────────────────────────────────────────

    private void HandleLook(Touch touch)
    {
        if (touch.phase == UnityEngine.InputSystem.TouchPhase.Began)
        {
            _lookTouchId = touch.touchId;
        }

        if (touch.touchId != _lookTouchId) return;

        // Use delta rather than absolute position for smoother look
        Vector2 delta = touch.delta * lookSensitivity;
        InputManager.Instance.lookInput = new Vector2(delta.x, delta.y);
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private static bool IsInRect(float normX, float normY, Rect r)
    {
        return normX >= r.x && normX <= r.x + r.width &&
               normY >= r.y && normY <= r.y + r.height;
    }
}
