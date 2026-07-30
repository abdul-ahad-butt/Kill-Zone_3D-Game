extends Node3D

var plant_time_required = 5.0
var defuse_time_required = 5.0

var current_plant_time = 0.0
var current_defuse_time = 0.0

var is_planting = false
var is_defusing = false

var interacting_player = null

func _ready():
	MatchManager.round_ended.connect(_on_round_ended)

func _on_round_ended(winner: int, reason: String):
	if reason == "Bomb Exploded":
		var explosion = load("res://scenes/effects/bomb_explosion.tscn")
		if explosion:
			var e = explosion.instantiate()
			var world = get_node_or_null("/root/World")
			if world: world.add_child(e)
			e.global_position = global_position
		queue_free()

func _process(delta):
	if is_planting and interacting_player:
		if interacting_player.velocity.length() > 0.1:
			cancel_interaction()
			return
			
		current_plant_time += delta
		get_tree().call_group("hud", "show_interact_progress", current_plant_time / plant_time_required, "PLANTING BOMB...")
		if current_plant_time >= plant_time_required:
			finish_planting()
			
	elif is_defusing and interacting_player:
		if interacting_player.velocity.length() > 0.1 or interacting_player.current_health <= 0:
			cancel_interaction()
			return
			
		current_defuse_time += delta
		get_tree().call_group("hud", "show_interact_progress", current_defuse_time / defuse_time_required, "DEFUSING BOMB...")
		if current_defuse_time >= defuse_time_required:
			finish_defusing()

func start_planting(player):
	if MatchManager.is_bomb_planted or MatchManager.current_state != MatchManager.MatchState.LIVE:
		return
	is_planting = true
	interacting_player = player
	current_plant_time = 0.0
	if not interacting_player.health_changed.is_connected(_on_player_damaged):
		interacting_player.health_changed.connect(_on_player_damaged)
	print("Started planting bomb...")

func start_defusing(player):
	if not MatchManager.is_bomb_planted or MatchManager.current_state != MatchManager.MatchState.LIVE:
		return
	is_defusing = true
	interacting_player = player
	current_defuse_time = 0.0
	if not interacting_player.health_changed.is_connected(_on_player_damaged):
		interacting_player.health_changed.connect(_on_player_damaged)
	print("Started defusing bomb...")

func _on_player_damaged(new_health, amount):
	if amount < 0:
		cancel_interaction()

func cancel_interaction():
	if interacting_player and interacting_player.health_changed.is_connected(_on_player_damaged):
		interacting_player.health_changed.disconnect(_on_player_damaged)
	is_planting = false
	is_defusing = false
	interacting_player = null
	current_plant_time = 0.0
	current_defuse_time = 0.0
	get_tree().call_group("hud", "hide_interact_progress")
	print("Bomb interaction canceled.")

func finish_planting():
	if interacting_player and interacting_player.health_changed.is_connected(_on_player_damaged):
		interacting_player.health_changed.disconnect(_on_player_damaged)
	is_planting = false
	if "has_bomb" in interacting_player:
		interacting_player.has_bomb = false
	interacting_player = null
	global_position = get_parent().global_position
	MatchManager.plant_bomb()
	get_tree().call_group("hud", "hide_interact_progress")
	print("Bomb Planted!")

func finish_defusing():
	if interacting_player and interacting_player.health_changed.is_connected(_on_player_damaged):
		interacting_player.health_changed.disconnect(_on_player_damaged)
	is_defusing = false
	interacting_player = null
	MatchManager.defuse_bomb()
	get_tree().call_group("hud", "hide_interact_progress")
	print("Bomb Defused!")

