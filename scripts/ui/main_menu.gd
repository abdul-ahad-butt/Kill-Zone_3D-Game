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

func _on_solo_pressed() -> void:
	print("Mode selected: Play Solo")
	MatchManager.is_offline_solo = true
	mode_select.hide()
	match_size_select.show()

func _on_multiplayer_pressed() -> void:
	print("Mode selected: Multiplayer")
	network_lbl.show()
	solo_btn.hide()
	multi_btn.hide()

func _on_match_size_pressed(ms: MatchManager.MatchSize) -> void:
	MatchManager.match_size = ms
	print("Match Size selected: ", "SOLO" if ms == MatchManager.MatchSize.SOLO else "5v5")
	match_size_select.hide()
	faction_select.show()
	selected_faction = Team.TeamId.NONE
	start_btn.disabled = true
	_update_faction_buttons()

func _on_faction_pressed(faction: Team.TeamId) -> void:
	var f_name = "POLICE" if faction == Team.TeamId.POLICE else "TERRORIST"
	print("Faction button pressed: ", f_name)
	selected_faction = faction
	start_btn.disabled = false
	_update_faction_buttons()

func _update_faction_buttons() -> void:
	police_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == Team.TeamId.POLICE else Color.WHITE)
	terrorist_btn.add_theme_color_override("font_color", Color.GREEN if selected_faction == Team.TeamId.TERRORIST else Color.WHITE)

func _on_back_pressed() -> void:
	faction_select.hide()
	match_size_select.hide()
	mode_select.show()

func _on_start_pressed() -> void:
	print("Start Game pressed with faction: ", selected_faction)
	MatchManager.solo_faction = selected_faction
	get_tree().change_scene_to_file("res://node_3d.tscn")
