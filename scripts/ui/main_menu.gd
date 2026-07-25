extends Control

@onready var mode_select = $ModeSelect
@onready var solo_btn = $ModeSelect/SoloButton
@onready var multi_btn = $ModeSelect/MultiplayerButton
@onready var network_lbl = $ModeSelect/NetworkLabel

@onready var faction_select = $FactionSelect
@onready var police_btn = $FactionSelect/HBoxContainer/PoliceButton
@onready var terrorist_btn = $FactionSelect/HBoxContainer/TerroristButton
@onready var start_btn = $FactionSelect/StartButton
@onready var back_btn = $FactionSelect/BackButton

@onready var match_size_select = $MatchSizeSelect
@onready var ms_solo_btn = $MatchSizeSelect/SoloButton
@onready var ms_5v5_btn = $MatchSizeSelect/FiveVFiveButton

var selected_faction: Team.TeamId = Team.TeamId.NONE
var selected_weapon: Resource = null
var weapon_box: HBoxContainer
var rifle_btn: Button
var smg_btn: Button
var sniper_btn: Button
var shotgun_btn: Button

var network_box: VBoxContainer
var host_btn: Button
var join_btn: Button
var ip_input: LineEdit

var is_hosting: bool = false
var join_ip: String = ""

var dummy_audio: AudioStreamPlayer

var rifle_data = preload("res://resources/weapon_data/Rifle.tres")
var smg_data = preload("res://resources/weapon_data/SMG.tres")
var sniper_data = preload("res://resources/weapon_data/Sniper.tres")
var shotgun_data = preload("res://resources/weapon_data/Shotgun.tres")

func _ready() -> void:
	print("MainMenu ready")
	
	# Initial UI State
	mode_select.show()
	match_size_select.hide()
	faction_select.hide()
	network_lbl.hide()
	start_btn.disabled = true
	
	# Connect Mode buttons
	solo_btn.pressed.connect(_on_solo_pressed)
	multi_btn.pressed.connect(_on_multiplayer_pressed)
	
	# Connect Match Size buttons
	ms_solo_btn.pressed.connect(func(): _on_match_size_pressed(MatchManager.MatchSize.SOLO))
	ms_5v5_btn.pressed.connect(func(): _on_match_size_pressed(MatchManager.MatchSize.FIVE_V_FIVE))
	
	# Connect Faction buttons
	police_btn.pressed.connect(func(): _on_faction_pressed(Team.TeamId.POLICE))
	terrorist_btn.pressed.connect(func(): _on_faction_pressed(Team.TeamId.TERRORIST))
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	# Build Weapon Select UI dynamically
	weapon_box = HBoxContainer.new()
	weapon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_box.add_theme_constant_override("separation", 20)
	weapon_box.hide()
	
	rifle_btn = Button.new()
	rifle_btn.text = "Rifle + Pistol"
	rifle_btn.custom_minimum_size = Vector2(180, 60)
	rifle_btn.add_theme_font_size_override("font_size", 20)
	rifle_btn.pressed.connect(func(): _on_weapon_selected(rifle_data))
	
	smg_btn = Button.new()
	smg_btn.text = "SMG + Pistol"
	smg_btn.custom_minimum_size = Vector2(180, 60)
	smg_btn.add_theme_font_size_override("font_size", 20)
	smg_btn.pressed.connect(func(): _on_weapon_selected(smg_data))
	
	weapon_box.add_child(rifle_btn)
	weapon_box.add_child(smg_btn)
	
	sniper_btn = Button.new()
	sniper_btn.text = "Sniper + Pistol"
	sniper_btn.custom_minimum_size = Vector2(180, 60)
	sniper_btn.add_theme_font_size_override("font_size", 20)
	sniper_btn.pressed.connect(func(): _on_weapon_selected(sniper_data))
	
	shotgun_btn = Button.new()
	shotgun_btn.text = "Shotgun + Pistol"
	shotgun_btn.custom_minimum_size = Vector2(180, 60)
	shotgun_btn.add_theme_font_size_override("font_size", 20)
	shotgun_btn.pressed.connect(func(): _on_weapon_selected(shotgun_data))
	
	weapon_box.add_child(sniper_btn)
	weapon_box.add_child(shotgun_btn)
	
	# Build Network UI dynamically
	network_box = VBoxContainer.new()
	network_box.alignment = BoxContainer.ALIGNMENT_CENTER
	network_box.add_theme_constant_override("separation", 15)
	network_box.hide()
	
	host_btn = Button.new()
	host_btn.text = "Host Game"
	host_btn.custom_minimum_size = Vector2(250, 60)
	host_btn.add_theme_font_size_override("font_size", 24)
	host_btn.pressed.connect(_on_host_pressed)
	
	join_btn = Button.new()
	join_btn.text = "Join Game"
	join_btn.custom_minimum_size = Vector2(250, 60)
	join_btn.add_theme_font_size_override("font_size", 24)
	join_btn.pressed.connect(_on_join_pressed)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Enter IP Address (e.g. 127.0.0.1)"
	ip_input.custom_minimum_size = Vector2(250, 40)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.text = "127.0.0.1"
	
	network_box.add_child(host_btn)
	network_box.add_child(ip_input)
	network_box.add_child(join_btn)
	
	add_child(network_box)
	network_box.set_anchors_preset(Control.PRESET_CENTER)
	
	# Add it above the start button
	var start_idx = start_btn.get_index()
	faction_select.add_child(weapon_box)
	faction_select.move_child(weapon_box, start_idx)

	# Build AudioContext Fixer
	dummy_audio = AudioStreamPlayer.new()
	add_child(dummy_audio)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_unlock_audio()

func _unlock_audio():
	if dummy_audio and not dummy_audio.playing:
		# Just play empty stream or nothing to unlock AudioContext
		dummy_audio.play()

func _on_solo_pressed() -> void:
	print("Menu flow: Mode selected -> Play Solo (OFFLINE)")
	MatchManager.is_offline_solo = true
	mode_select.hide()
	match_size_select.show()

func _on_multiplayer_pressed() -> void:
	print("Menu flow: Mode selected -> Multiplayer")
	mode_select.hide()
	network_box.show()

func _on_host_pressed() -> void:
	print("Menu flow: Network -> Host Game")
	is_hosting = true
	MatchManager.is_offline_solo = false
	network_box.hide()
	match_size_select.show()

func _on_join_pressed() -> void:
	print("Menu flow: Network -> Join Game")
	is_hosting = false
	join_ip = ip_input.text.strip_edges()
	MatchManager.is_offline_solo = false
	network_box.hide()
	faction_select.show()
	selected_faction = Team.TeamId.NONE
	selected_weapon = null
	start_btn.disabled = true
	weapon_box.hide()
	_update_faction_buttons()

func _on_match_size_pressed(ms: MatchManager.MatchSize) -> void:
	MatchManager.match_size = ms
	print("Menu flow: Match Size selected -> ", "SOLO (OFFLINE)" if ms == MatchManager.MatchSize.SOLO else "5v5 TEAM MATCH (OFFLINE)")
	match_size_select.hide()
	faction_select.show()
	selected_faction = Team.TeamId.NONE
	selected_weapon = null
	start_btn.disabled = true
	weapon_box.hide()
	_update_faction_buttons()

func _on_faction_pressed(faction: Team.TeamId) -> void:
	var f_name = "POLICE" if faction == Team.TeamId.POLICE else "TERRORIST"
	print("Menu flow: Faction chosen -> ", f_name)
	selected_faction = faction
	selected_weapon = null
	start_btn.disabled = true
	_update_faction_buttons()
	
	weapon_box.show()
	if faction == Team.TeamId.POLICE:
		rifle_btn.show()
		sniper_btn.show()
		smg_btn.hide()
		shotgun_btn.hide()
	else:
		rifle_btn.show()
		smg_btn.show()
		shotgun_btn.show()
		sniper_btn.hide()
	
	_update_weapon_buttons()

func _on_weapon_selected(weapon: Resource) -> void:
	selected_weapon = weapon
	start_btn.disabled = false
	if selected_faction == Team.TeamId.TERRORIST:
		var w_name = "Rifle" if weapon == rifle_data else "SMG"
		print("Menu flow: Weapon chosen -> ", w_name)
	_update_weapon_buttons()

func _update_faction_buttons() -> void:
	police_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == Team.TeamId.POLICE else Color.WHITE)
	terrorist_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == Team.TeamId.TERRORIST else Color.WHITE)

func _update_weapon_buttons() -> void:
	rifle_btn.add_theme_color_override("font_color", Color.GREEN if selected_weapon == rifle_data else Color.WHITE)
	smg_btn.add_theme_color_override("font_color", Color.GREEN if selected_weapon == smg_data else Color.WHITE)
	sniper_btn.add_theme_color_override("font_color", Color.GREEN if selected_weapon == sniper_data else Color.WHITE)
	shotgun_btn.add_theme_color_override("font_color", Color.GREEN if selected_weapon == shotgun_data else Color.WHITE)

func _on_back_pressed() -> void:
	faction_select.hide()
	match_size_select.hide()
	mode_select.show()

func _on_start_pressed() -> void:
	print("Menu flow: Start Game pressed with Faction ", selected_faction, " and Weapon ", selected_weapon.resource_path.get_file())
	MatchManager.solo_faction = selected_faction
	MatchManager.solo_primary_weapon = selected_weapon
	
	if MatchManager.is_offline_solo:
		get_tree().change_scene_to_file("res://node_3d.tscn")
	elif is_hosting:
		NetworkManager.host_game()
	else:
		NetworkManager.join_game(join_ip)
