extends Node

var player: CharacterBody3D
var update_timer: float = 0.0
var target: CharacterBody3D = null

func _ready():
	player = get_parent() as CharacterBody3D

func _physics_process(delta):
	if not player or not player.is_bot or player.health <= 0:
		return
		
	update_timer -= delta
	if update_timer <= 0:
		update_timer = 0.5 # update target every 0.5s
		_find_target()
		
	if is_instance_valid(target) and target.health > 0:
		var to_target = target.global_position - player.global_position
		var dist = to_target.length()
		
		# Look at target
		var look_dir = to_target.normalized()
		player.rotation.y = atan2(look_dir.x, look_dir.z)
		
		# Pitch camera
		if player.camera:
			player.camera.rotation.x = asin(look_dir.y)
			
		# Fire if in range and line of sight
		if dist < 20.0 and _has_line_of_sight(target):
			player.bot_wants_fire = true
			player.bot_input_dir = Vector2.ZERO # Stop to shoot
		else:
			player.bot_wants_fire = false
			# Move towards target
			var move_dir = Vector2(look_dir.x, look_dir.z).normalized()
			player.bot_input_dir = move_dir
	else:
		player.bot_wants_fire = false
		player.bot_input_dir = Vector2.ZERO
		
		# Simple wander if no target
		if randf() < 0.02:
			player.bot_input_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			
		if player.bot_input_dir != Vector2.ZERO:
			player.rotation.y = atan2(player.bot_input_dir.x, player.bot_input_dir.y)

func _find_target():
	var closest_dist = 9999.0
	target = null
	
	for p in get_tree().get_nodes_in_group("Players"):
		if p != player and p.team != player.team and p.health > 0:
			var d = player.global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				target = p

func _has_line_of_sight(t: Node3D) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 1.5, 0), 
		t.global_position + Vector3(0, 1.5, 0)
	)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.collider == t
	return false
