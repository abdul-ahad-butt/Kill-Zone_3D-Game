extends Node

enum State { IDLE, PATROL, CHASE, ATTACK, RETREAT, OBJECTIVE }
var current_state: State = State.IDLE

var player: CharacterBody3D
var nav_agent: NavigationAgent3D
var update_timer: float = 0.0
var target_enemy: CharacterBody3D = null
var current_objective: Node3D = null

var strafe_timer: float = 0.0
var current_strafe_dir: Vector2 = Vector2.ZERO

var last_known_enemy_pos: Vector3 = Vector3.ZERO
var patrol_target_pos: Vector3 = Vector3.ZERO
var retreat_target_pos: Vector3 = Vector3.ZERO

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
	player.bot_wants_reload = false
	player.bot_wants_walk = false
	player.bot_input_dir = Vector2.ZERO
	
	update_timer -= delta
	if update_timer <= 0:
		if MatchManager.bot_difficulty == 0: update_timer = 1.0
		elif MatchManager.bot_difficulty == 2: update_timer = 0.2
		else: update_timer = 0.5
		_update_bot_brain()
		
	_execute_state(delta)

func _update_bot_brain():
	_find_closest_enemy()
	_evaluate_objective()
	
	var enemy_visible = is_instance_valid(target_enemy) and target_enemy.health > 0 and _has_line_of_sight(target_enemy)
	
	if enemy_visible:
		last_known_enemy_pos = target_enemy.global_position
		
	# State Transitions
	if enemy_visible:
		var health_ratio = player.health / 100.0
		var ammo_ratio = 1.0
		if player.current_weapon:
			ammo_ratio = float(player.current_ammo) / float(player.current_weapon.mag_size)
			
		if (health_ratio < 0.3 or ammo_ratio == 0.0) and current_state != State.RETREAT:
			_enter_state(State.RETREAT)
		else:
			_enter_state(State.ATTACK)
	else:
		if current_state == State.ATTACK:
			_enter_state(State.CHASE)
		elif current_state != State.CHASE and current_state != State.RETREAT:
			if is_instance_valid(current_objective):
				_enter_state(State.OBJECTIVE)
			elif current_state == State.IDLE:
				_enter_state(State.PATROL)

func _enter_state(new_state: State):
	if current_state == new_state: return
	current_state = new_state
	
	if current_state == State.PATROL:
		# Pick a random spot nearby
		var random_offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		patrol_target_pos = player.global_position + random_offset
	elif current_state == State.RETREAT:
		# Run away from enemy
		if is_instance_valid(target_enemy):
			var away_dir = (player.global_position - target_enemy.global_position).normalized()
			retreat_target_pos = player.global_position + away_dir * 20.0

func _execute_state(delta: float):
	match current_state:
		State.IDLE:
			pass
		State.PATROL:
			_move_to_position(patrol_target_pos, delta)
			if player.global_position.distance_to(patrol_target_pos) < 2.0:
				_enter_state(State.IDLE)
				
		State.CHASE:
			player.bot_wants_walk = true # Sneak while investigating
			_move_to_position(last_known_enemy_pos, delta)
			if player.global_position.distance_to(last_known_enemy_pos) < 2.0:
				_enter_state(State.IDLE)
				
		State.ATTACK:
			if not is_instance_valid(target_enemy): return
			var to_target = target_enemy.global_position - player.global_position
			var look_dir = to_target.normalized()
			
			var aim_speed = 12.0
			if MatchManager.bot_difficulty == 0: aim_speed = 5.0
			elif MatchManager.bot_difficulty == 2: aim_speed = 30.0
			
			player.rotation.y = lerp_angle(player.rotation.y, atan2(look_dir.x, look_dir.z), delta * aim_speed)
			if player.camera:
				player.camera.rotation.x = lerp_angle(player.camera.rotation.x, asin(look_dir.y), delta * (aim_speed * 1.25))
				
			if to_target.length() < 40.0:
				player.bot_wants_fire = true
				
			# Dynamic Strafing
			strafe_timer -= delta
			if strafe_timer <= 0:
				strafe_timer = randf_range(0.5, 1.5)
				var r = randf()
				if r < 0.4: current_strafe_dir = Vector2(-1, 0)
				elif r < 0.8: current_strafe_dir = Vector2(1, 0)
				else: current_strafe_dir = Vector2.ZERO
			player.bot_input_dir = current_strafe_dir
			
		State.RETREAT:
			_move_to_position(retreat_target_pos, delta)
			if player.current_ammo == 0:
				player.bot_wants_reload = true
			if player.global_position.distance_to(retreat_target_pos) < 2.0:
				_enter_state(State.IDLE)
				
		State.OBJECTIVE:
			if not is_instance_valid(current_objective): return
			var dist = player.global_position.distance_to(current_objective.global_position)
			if dist < 3.0:
				var look_dir = (current_objective.global_position - player.global_position).normalized()
				player.rotation.y = lerp_angle(player.rotation.y, atan2(look_dir.x, look_dir.z), delta * 10.0)
				player.bot_wants_interact = true
			else:
				_move_to_position(current_objective.global_position, delta)

func _move_to_position(pos: Vector3, delta: float):
	nav_agent.target_position = pos
	var next_path_pos = nav_agent.get_next_path_position()
	var move_dir_3d = (next_path_pos - player.global_position).normalized()
	
	if move_dir_3d.length_squared() > 0.01:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(move_dir_3d.x, move_dir_3d.z), delta * 10.0)
		player.bot_input_dir = Vector2(0, 1) # Forward

func hear_footstep(source: CharacterBody3D):
	if current_state != State.ATTACK:
		target_enemy = source
		last_known_enemy_pos = source.global_position
		_enter_state(State.CHASE)
		update_timer = 0.1

func _find_closest_enemy():
	var closest_dist = 9999.0
	var new_target = null
	for p in get_tree().get_nodes_in_group("Players"):
		if p != player and p.team != player.team and p.health > 0:
			var d = player.global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				new_target = p
	target_enemy = new_target

func _evaluate_objective():
	current_objective = null
	if MatchManager.match_size == MatchManager.MatchSize.SOLO: return
	
	if player.team == Team.TeamId.TERRORIST:
		if player.has_bomb and not MatchManager.is_bomb_planted:
			var closest_dist = 9999.0
			for site in get_tree().get_nodes_in_group("BombSite"):
				if site.is_active:
					var d = player.global_position.distance_to(site.global_position)
					if d < closest_dist:
						closest_dist = d
						current_objective = site
	elif player.team == Team.TeamId.POLICE:
		if MatchManager.is_bomb_planted:
			for site in get_tree().get_nodes_in_group("BombSite"):
				if site.is_active and site.global_position.distance_to(MatchManager.bomb_position) < 5.0:
					current_objective = site
					break

func _has_line_of_sight(t: Node3D) -> bool:
	if not is_instance_valid(t) or not is_instance_valid(player): return false
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
