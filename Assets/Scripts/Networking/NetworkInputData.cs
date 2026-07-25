using Fusion;
using UnityEngine;

public struct NetworkInputData : INetworkInput
{
    public Vector2 moveInput;
    public Vector2 lookInput;
    public NetworkButtons buttons;

    public const int BUTTON_JUMP = 0;
    public const int BUTTON_FIRE = 1;
    public const int BUTTON_USE = 2;
}
