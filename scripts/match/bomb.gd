extends Node3D

var plant_time_required = 3.5
var defuse_time_required = 5.0

var current_plant_time = 0.0
var current_defuse_time = 0.0

var is_planting = false
var is_defusing = false

var interacting_player = null

func _process(delta):
	if is_planting and interacting_player:
		if interacting_player.velocity.length() > 0.1:
			cancel_interaction()
			return
			
		current_plant_time += delta
		if current_plant_time >= plant_time_required:
			finish_planting()
			
	elif is_defusing and interacting_player:
		if interacting_player.velocity.length() > 0.1 or interacting_player.health <= 0:
			cancel_interaction()
			return
			
		current_defuse_time += delta
		if current_defuse_time >= defuse_time_required:
			finish_defusing()

func start_planting(player):
	if MatchManager.is_bomb_planted or MatchManager.current_state != MatchManager.MatchState.LIVE:
		return
	is_planting = true
	interacting_player = player
	current_plant_time = 0.0
	print("Started planting bomb...")

func start_defusing(player):
	if not MatchManager.is_bomb_planted or MatchManager.current_state != MatchManager.MatchState.LIVE:
		return
	is_defusing = true
	interacting_player = player
	current_defuse_time = 0.0
	print("Started defusing bomb...")

func cancel_interaction():
	is_planting = false
	is_defusing = false
	interacting_player = null
	current_plant_time = 0.0
	current_defuse_time = 0.0
	print("Bomb interaction canceled.")

func finish_planting():
	is_planting = false
	interacting_player.has_bomb = false
	interacting_player = null
	# Move bomb model to player's feet
	global_position = get_parent().global_position
	MatchManager.plant_bomb()
	print("Bomb Planted!")

func finish_defusing():
	is_defusing = false
	interacting_player = null
	MatchManager.defuse_bomb()
	print("Bomb Defused!")
