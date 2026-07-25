using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Purely visual virtual joystick.
/// TouchInputLayer drives the logic; this script only moves UI elements.
/// Attach to a Canvas child that contains a background ring and a thumb nub Image.
/// </summary>
public class VirtualJoystickUI : MonoBehaviour
{
    [Header("UI Elements")]
    public RectTransform joystickBackground; // The outer ring
    public RectTransform joystickThumb;      // The inner nub

    [Header("Clamp")]
    public float maxThumbRadius = 60f;       // Max pixels thumb can move from centre

    private Vector2 _backgroundAnchor; // Screen-space origin set when touch begins

    private void Awake()
    {
        // Hide on non-mobile so it doesn't clutter the Editor
        if (!Application.isMobilePlatform)
        {
            gameObject.SetActive(false);
        }
    }

    /// <summary>
    /// Called every frame by TouchInputLayer.
    /// <paramref name="originScreen"/> — screen-space pixel where the touch began.
    /// <paramref name="deltaPx"/>      — raw pixel delta from origin.
    /// Pass (Vector2.zero, Vector2.zero) to hide the joystick.
    /// </summary>
    public void SetThumbPosition(Vector2 originScreen, Vector2 deltaPx)
    {
        if (joystickBackground == null || joystickThumb == null) return;

        bool active = originScreen != Vector2.zero || deltaPx != Vector2.zero;

        joystickBackground.gameObject.SetActive(active);

        if (!active) return;

        // Convert screen-space origin to canvas local space
        Canvas canvas = GetComponentInParent<Canvas>();
        if (canvas == null) return;

        RectTransformUtility.ScreenPointToLocalPointInRectangle(
            canvas.transform as RectTransform,
            originScreen,
            canvas.worldCamera,
            out Vector2 localOrigin);

        joystickBackground.anchoredPosition = localOrigin;

        // Clamp thumb within max radius
        Vector2 clampedDelta = Vector2.ClampMagnitude(deltaPx, maxThumbRadius);

        // deltaPx is in screen pixels; convert to canvas units
        float scaleFactor = canvas.scaleFactor > 0 ? canvas.scaleFactor : 1f;
        joystickThumb.anchoredPosition = clampedDelta / scaleFactor;
    }
}
