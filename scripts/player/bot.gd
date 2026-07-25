extends CharacterBody3D

const SPEED = 3.0

@export var team: Team.TeamId = Team.TeamId.TERRORIST
@export var health: int = 100

@onready var nav_agent = $NavigationAgent3D
@onready var timer = $Timer
@onready var mesh = $MeshInstance3D

var target_position: Vector3

enum State {
	PATROL,
	ENGAGE
}
var current_state: State = State.PATROL
var current_target: CharacterBody3D = null
var shoot_timer: float = 0.0

func _ready():
	if mesh:
		mesh.queue_free()
		
	var soldier = load("res://scenes/player/tactical_soldier.tscn").instantiate()
	soldier.team = team
	soldier.name = "TacticalSoldier"
	add_child(soldier)
	
	# Wait for first physics frame to ensure navmesh is ready
	await get_tree().physics_frame
	pick_new_target()
	timer.start(5.0)

func pick_new_target():
	var nearest_dist = 9999.0
	var nearest_pos = global_position
	var nearest_pos_node: CharacterBody3D = null
	
	var all_nodes = get_tree().get_nodes_in_group("players") # Assuming players are in a group, wait, they aren't.
	# Let's just find all CharacterBody3D in the world.
	var world_node = get_parent()
	if world_node:
		for child in world_node.get_children():
			if child is CharacterBody3D and child != self and child.has_method("take_damage"):
				var is_enemy = false
				if not NetworkManager.is_team_mode:
					is_enemy = true
				elif child.team != team:
					is_enemy = true
					
				if is_enemy:
					var dist = global_position.distance_to(child.global_position)
					if dist < nearest_dist:
						nearest_dist = dist
						nearest_pos = child.global_position
						nearest_pos_node = child
						
	if nearest_dist < 9999.0:
		current_target = nearest_pos_node
		target_position = nearest_pos
	else:
		current_target = null
		var random_offset = Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
		target_position = global_position + random_offset
		
	nav_agent.target_position = target_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if current_target and is_instance_valid(current_target) and current_target.has_method("take_damage") and current_target.health > 0:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), current_target.global_position + Vector3(0, 1.5, 0))
		query.exclude = [self]
		query.collision_mask = 5 # World and players
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == current_target:
			current_state = State.ENGAGE
		else:
			current_state = State.PATROL
			nav_agent.target_position = current_target.global_position
	else:
		current_state = State.PATROL
		if randf() < 0.01:
			pick_new_target()

	if current_state == State.ENGAGE:
		velocity.x = 0
		velocity.z = 0
		var look_pos = current_target.global_position
		look_pos.y = global_position.y
		look_at(look_pos, Vector3.UP)
		
		var sol = get_node_or_null("TacticalSoldier")
		if sol: sol.play_anim("idle")
		
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			shoot_timer = randf_range(0.2, 0.6)
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_2d(am.gunshot_sound)
			
			rpc("client_muzzle_flash")
			
			if current_target.has_method("take_damage"):
				current_target.take_damage(15, team, 999)
				var hit_pos = current_target.global_position + Vector3(0, 1.0, 0)
				rpc("client_spawn_impact", hit_pos, Vector3.UP, true)
				
	elif current_state == State.PATROL:
		if nav_agent.is_navigation_finished():
			velocity.x = 0
			velocity.z = 0
		else:
			var current_agent_position: Vector3 = global_position
			var next_path_position: Vector3 = nav_agent.get_next_path_position()
			
			var new_velocity: Vector3 = next_path_position - current_agent_position
			new_velocity = new_velocity.normalized()
			new_velocity = new_velocity * SPEED
			
			velocity.x = move_toward(velocity.x, new_velocity.x, 0.25)
			velocity.z = move_toward(velocity.z, new_velocity.z, 0.25)
			
			# Look at target
			if new_velocity.length() > 0.1:
				var look_target = global_position + Vector3(velocity.x, 0, velocity.z)
				look_at(look_target, Vector3.UP)
				var sol = get_node_or_null("TacticalSoldier")
				if sol: sol.play_anim("run")
			else:
				var sol = get_node_or_null("TacticalSoldier")
				if sol: sol.play_anim("idle")

	move_and_slide()

func _on_timer_timeout():
	pick_new_target()

func take_damage(amount: int, attacker_team: Team.TeamId, attacker_id: int = 1):
	if NetworkManager.is_team_mode and attacker_team == team: return
	health -= amount
	if health <= 0:
		die(attacker_id)

func die(attacker_id: int):
	PlayerStats.record_kill_event(attacker_id, 999, "Bot")
	queue_free()

@rpc("authority", "call_local", "unreliable")
func client_spawn_impact(pos: Vector3, normal: Vector3, is_blood: bool):
	var effect_scene
	if is_blood:
		effect_scene = load("res://scenes/effects/blood_impact.tscn")
	else:
		effect_scene = load("res://scenes/effects/wall_impact.tscn")
		
	if effect_scene:
		var effect = effect_scene.instantiate()
		get_node("/root/World").add_child(effect)
		effect.global_position = pos
		if normal != Vector3.UP and normal != Vector3.DOWN:
			effect.look_at(pos + normal, Vector3.UP)
		elif normal == Vector3.UP:
			effect.rotation_degrees.x = -90
		else:
			effect.rotation_degrees.x = 90

@rpc("authority", "call_local", "unreliable")
func client_muzzle_flash():
	var flash_scene = load("res://scenes/effects/muzzle_flash.tscn")
	if flash_scene:
		var f = flash_scene.instantiate()
		add_child(f)
		f.position = Vector3(0, 1.2, 0.5)
		f.emitting = true
		get_tree().create_timer(0.1).timeout.connect(f.queue_free)
