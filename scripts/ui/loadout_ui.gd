extends Control

@export var local_player: Node3D # Assigned to the player this UI controls
@export var rifle_data: WeaponData
@export var smg_data: WeaponData
@export var sniper_data: WeaponData
@export var shotgun_data: WeaponData

@onready var rifle_btn = $HBoxContainer/RifleButton
@onready var smg_btn = $HBoxContainer/SMGButton
@onready var sniper_btn = $HBoxContainer/SniperButton
@onready var shotgun_btn = $HBoxContainer/ShotgunButton

func _ready():
	MatchManager.round_state_changed.connect(_on_state_changed)
	
	rifle_btn.pressed.connect(func(): _select_weapon(rifle_data))
	smg_btn.pressed.connect(func(): _select_weapon(smg_data))
	sniper_btn.pressed.connect(func(): _select_weapon(sniper_data))
	shotgun_btn.pressed.connect(func(): _select_weapon(shotgun_data))
	
	hide()

func _on_state_changed(new_state):
	if new_state == MatchManager.MatchState.ROUND_START:
		if local_player and local_player.team == Team.TeamId.TERRORIST:
			show()
	else:
		hide()

func _select_weapon(weapon_data: WeaponData):
	if local_player:
		local_player.primary_weapon = weapon_data
		local_player.equip_weapon(weapon_data)
	hide()
