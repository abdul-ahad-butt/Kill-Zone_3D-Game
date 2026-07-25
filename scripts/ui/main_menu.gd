extends Control

@onready var host_btn = $VBoxContainer/HostButton
@onready var join_btn = $VBoxContainer/JoinButton
@onready var ip_input = $VBoxContainer/IPInput

var _graphics_ui: CanvasLayer = null

func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)

	NetworkManager.player_connected.connect(_on_player_connected)

	# Attach the graphics settings panel to the main menu
	_graphics_ui = load("res://scripts/ui/graphics_settings_ui.gd").new()
	_graphics_ui.name = "GraphicsSettingsUI"
	add_child(_graphics_ui)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle graphics panel with G key or three-finger tap on mobile
	if event.is_action_pressed("ui_cancel"):
		if _graphics_ui:
			_graphics_ui.toggle_panel()

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	hide()
	# In a real game, you would transition to the lobby or main level here

func _on_join_pressed() -> void:
	var ip := ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	hide()

func _on_player_connected(id: int) -> void:
	print("Main menu sees player connected: ", id)
