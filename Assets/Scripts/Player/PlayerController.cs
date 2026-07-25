using Fusion;
using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class PlayerController : NetworkBehaviour
{
    [Header("Movement Settings")]
    public float moveSpeed = 5f;
    public float gravity = -9.81f;
    public float jumpHeight = 1.2f;

    [Header("Look Settings")]
    public Transform playerCamera;
    public float lookSensitivity = 1f;
    public float maxLookAngle = 80f;

    private CharacterController controller;
    private Vector3 velocity;
    private float xRotation = 0f;

    public override void Spawned()
    {
        controller = GetComponent<CharacterController>();
        if (playerCamera == null)
        {
            playerCamera = GetComponentInChildren<Camera>()?.transform;
        }

        if (HasInputAuthority)
        {
            // Lock cursor for local player
            Cursor.lockState = CursorLockMode.Locked;
        }
        else
        {
            // Disable camera for remote players
            if (playerCamera != null)
                playerCamera.gameObject.SetActive(false);
        }
    }

    public override void FixedUpdateNetwork()
    {
        if (GetInput(out NetworkInputData input))
        {
            HandleLook(input);
            HandleMovement(input);
        }
    }

    private void HandleMovement(NetworkInputData input)
    {
        bool isGrounded = controller.isGrounded;
        if (isGrounded && velocity.y < 0)
        {
            velocity.y = -2f;
        }

        Vector3 move = transform.right * input.moveInput.x + transform.forward * input.moveInput.y;
        controller.Move(move * moveSpeed * Runner.DeltaTime);

        if (input.buttons.IsSet(NetworkInputData.BUTTON_JUMP) && isGrounded)
        {
            velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
        }

        velocity.y += gravity * Runner.DeltaTime;
        controller.Move(velocity * Runner.DeltaTime);
    }

    private void HandleLook(NetworkInputData input)
    {
        float mouseX = input.lookInput.x * lookSensitivity;
        float mouseY = input.lookInput.y * lookSensitivity;

        xRotation -= mouseY;
        xRotation = Mathf.Clamp(xRotation, -maxLookAngle, maxLookAngle);

        if (playerCamera != null)
        {
            playerCamera.localRotation = Quaternion.Euler(xRotation, 0f, 0f);
        }
        
        transform.Rotate(Vector3.up * mouseX);
    }
}
