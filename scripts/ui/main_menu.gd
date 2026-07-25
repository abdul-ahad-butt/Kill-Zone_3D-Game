extends Control

@onready var solo_btn = $VBoxContainer/SoloButton
@onready var team_btn = $VBoxContainer/TeamButton
@onready var join_btn = $VBoxContainer/JoinButton
@onready var ip_input = $VBoxContainer/IPInput
@onready var faction_container = $VBoxContainer/FactionContainer
@onready var police_btn = $VBoxContainer/FactionContainer/PoliceButton
@onready var terrorist_btn = $VBoxContainer/FactionContainer/TerroristButton
@onready var start_game_btn = $VBoxContainer/FactionContainer/StartGameButton

@onready var settings_btn = $VBoxContainer/SettingsButton
@onready var settings_container = $VBoxContainer/SettingsContainer
@onready var qual_low_btn = $VBoxContainer/SettingsContainer/QualityLowBtn
@onready var qual_med_btn = $VBoxContainer/SettingsContainer/QualityMedBtn
@onready var qual_high_btn = $VBoxContainer/SettingsContainer/QualityHighBtn
@onready var settings_back_btn = $VBoxContainer/SettingsContainer/SettingsBackBtn

var is_team_mode: bool = false
var selected_faction: int = 1 # 1 = Police, 2 = Terrorist

func _ready():
	solo_btn.pressed.connect(_on_solo_pressed)
	team_btn.pressed.connect(_on_team_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	police_btn.pressed.connect(_on_police_pressed)
	terrorist_btn.pressed.connect(_on_terrorist_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	
	settings_btn.pressed.connect(_show_settings)
	settings_back_btn.pressed.connect(_hide_settings)
	qual_low_btn.pressed.connect(func(): _set_quality(GraphicsManager.Quality.LOW))
	qual_med_btn.pressed.connect(func(): _set_quality(GraphicsManager.Quality.MEDIUM))
	qual_high_btn.pressed.connect(func(): _set_quality(GraphicsManager.Quality.HIGH))
	
	start_game_btn.disabled = true
	
	NetworkManager.player_connected.connect(_on_player_connected)

func _show_faction_selection():
	solo_btn.hide()
	team_btn.hide()
	ip_input.hide()
	join_btn.hide()
	settings_btn.hide()
	faction_container.show()
	_update_faction_visuals()

func _show_settings():
	solo_btn.hide()
	team_btn.hide()
	ip_input.hide()
	join_btn.hide()
	settings_btn.hide()
	settings_container.show()
	_update_quality_visuals()

func _hide_settings():
	settings_container.hide()
	solo_btn.show()
	team_btn.show()
	ip_input.show()
	join_btn.show()
	settings_btn.show()

func _set_quality(q):
	GraphicsManager.set_quality(q)
	_update_quality_visuals()

func _update_quality_visuals():
	var q = GraphicsManager.get_quality()
	qual_low_btn.add_theme_color_override("font_color", Color.GREEN if q == GraphicsManager.Quality.LOW else Color.WHITE)
	qual_med_btn.add_theme_color_override("font_color", Color.GREEN if q == GraphicsManager.Quality.MEDIUM else Color.WHITE)
	qual_high_btn.add_theme_color_override("font_color", Color.GREEN if q == GraphicsManager.Quality.HIGH else Color.WHITE)

func _on_solo_pressed():
	is_team_mode = false
	_show_faction_selection()

func _on_team_pressed():
	is_team_mode = true
	_show_faction_selection()

func _on_police_pressed():
	selected_faction = 1
	start_game_btn.disabled = false
	_update_faction_visuals()

func _on_terrorist_pressed():
	selected_faction = 2
	start_game_btn.disabled = false
	_update_faction_visuals()

func _update_faction_visuals():
	if start_game_btn.disabled:
		police_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		terrorist_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		police_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == 1 else Color(0.4, 0.6, 1.0))
		terrorist_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == 2 else Color(1.0, 0.4, 0.4))

func _on_start_game_pressed():
	NetworkManager.start_offline(is_team_mode, selected_faction)
	hide()
	
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	# Disable the spectator camera
	var spectator = get_tree().current_scene.get_node_or_null("SpectatorCamera")
	if spectator:
		spectator.current = false
		
	var level = get_tree().current_scene
	if level and level.has_method("_spawn_local_offline"):
		level._spawn_local_offline()

func _on_join_pressed():
	var ip = ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	hide()

func _on_player_connected(id: int):
	print("Main menu sees player connected: ", id)
