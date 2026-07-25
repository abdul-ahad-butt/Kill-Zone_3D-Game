extends Node

var player: CharacterBody3D
var nav_agent: NavigationAgent3D
var update_timer: float = 0.0
var target_enemy: CharacterBody3D = null
var current_objective: Node3D = null

func _ready():
	player = get_parent() as CharacterBody3D
	nav_agent = player.get_node_or_null("NavigationAgent3D")
	
	if not nav_agent:
		print("Bot missing NavigationAgent3D!")

func _physics_process(delta):
	if not player or not player.is_bot or player.health <= 0 or not nav_agent:
		return
		
	# Reset inputs
	player.bot_wants_fire = false
	player.bot_wants_interact = false
	player.bot_input_dir = Vector2.ZERO
	
	update_timer -= delta
	if update_timer <= 0:
		update_timer = 0.5 # Update logic twice a second
		_update_bot_brain()
		
	# 1. Combat Priority (Stop and shoot if enemy is visible)
	if is_instance_valid(target_enemy) and target_enemy.health > 0 and _has_line_of_sight(target_enemy):
		var to_target = target_enemy.global_position - player.global_position
		var dist = to_target.length()
		
		# Look at target
		var look_dir = to_target.normalized()
		player.rotation.y = atan2(look_dir.x, look_dir.z)
		
		if player.camera:
			player.camera.rotation.x = asin(look_dir.y)
			
		if dist < 30.0:
			player.bot_wants_fire = true
			player.bot_input_dir = Vector2.ZERO # Stop to shoot accurately
			return # Skip objective pathing while shooting
			
	# 2. Objective Pathfinding
	if is_instance_valid(current_objective):
		# If we are close enough to objective, interact
		var dist_to_obj = player.global_position.distance_to(current_objective.global_position)
		if dist_to_obj < 3.0:
			player.bot_input_dir = Vector2.ZERO
			
			# Look at objective
			var look_dir = (current_objective.global_position - player.global_position).normalized()
			player.rotation.y = atan2(look_dir.x, look_dir.z)
			
			player.bot_wants_interact = true
			return
			
		# Otherwise, move to objective
		nav_agent.target_position = current_objective.global_position
		
		var next_path_pos = nav_agent.get_next_path_position()
		var move_dir_3d = (next_path_pos - player.global_position).normalized()
		
		# Convert 3D move dir to 2D local input
		# First rotate character to face the path
		player.rotation.y = lerp_angle(player.rotation.y, atan2(move_dir_3d.x, move_dir_3d.z), delta * 10.0)
		
		# Then input forward
		player.bot_input_dir = Vector2(0, 1) # Forward is positive Y in our input vector
	else:
		# 3. Simple Wander if no objective
		if randf() < 0.05:
			player.bot_input_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		if player.bot_input_dir != Vector2.ZERO:
			player.rotation.y = lerp_angle(player.rotation.y, atan2(player.bot_input_dir.x, player.bot_input_dir.y), delta * 5.0)

func _update_bot_brain():
	_find_closest_enemy()
	_evaluate_objective()
func hear_footstep(source: CharacterBody3D):
	if target_enemy == null or target_enemy.health <= 0 or not _has_line_of_sight(target_enemy):
		# Prioritize the player making noise if we aren't actively engaging someone we can see
		target_enemy = source
		# Face the noise immediately
		var look_dir = (source.global_position - player.global_position).normalized()
		player.rotation.y = atan2(look_dir.x, look_dir.z)
		# Force an update cycle soon
		update_timer = 0.1
func _find_closest_enemy():
	var closest_dist = 9999.0
	target_enemy = null
	
	for p in get_tree().get_nodes_in_group("Players"):
		if p != player and p.team != player.team and p.health > 0:
			var d = player.global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				target_enemy = p

func _evaluate_objective():
	current_objective = null
	
	if MatchManager.match_size == MatchManager.MatchSize.SOLO: return # No bomb objectives in deathmatch
	
	if player.team == Team.TeamId.TERRORIST:
		if player.has_bomb and not MatchManager.is_bomb_planted:
			# Find closest active bomb site
			var closest_dist = 9999.0
			for site in get_tree().get_nodes_in_group("BombSite"):
				if site.is_active:
					var d = player.global_position.distance_to(site.global_position)
					if d < closest_dist:
						closest_dist = d
						current_objective = site
						
	elif player.team == Team.TeamId.POLICE:
		if MatchManager.is_bomb_planted:
			# Find the bomb
			# The bomb effect/position is managed by MatchManager, but we can just find the active site
			# because plant_bomb moves the bomb visual there.
			for site in get_tree().get_nodes_in_group("BombSite"):
				if site.is_active and site.global_position.distance_to(MatchManager.bomb_position) < 5.0:
					current_objective = site
					break

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
