extends Control

@onready var host_btn = $VBoxContainer/HostButton
@onready var join_btn = $VBoxContainer/JoinButton
@onready var ip_input = $VBoxContainer/IPInput

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	NetworkManager.player_connected.connect(_on_player_connected)

func _on_host_pressed():
	NetworkManager.host_game()
	hide()
	# In a real game, you would transition to the lobby or main level here
	# For this prototype, the host just waits in the level for connections.

func _on_join_pressed():
	var ip = ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	hide()

func _on_player_connected(id: int):
	print("Main menu sees player connected: ", id)
