extends CharacterBody3D

const SPEED = 3.0

@export var team: Team.TeamId = Team.TeamId.TERRORIST
@export var health: int = 100

@onready var nav_agent = $NavigationAgent3D
@onready var timer = $Timer
@onready var mesh = $MeshInstance3D

var target_position: Vector3

func _ready():
	var mat = StandardMaterial3D.new()
	if team == Team.TeamId.POLICE:
		mat.albedo_color = Color(0.2, 0.4, 0.8) # Blue for CT
	else:
		mat.albedo_color = Color(0.8, 0.2, 0.2) # Red for T
	mesh.material_override = mat
	
	# Wait for first physics frame to ensure navmesh is ready
	await get_tree().physics_frame
	pick_new_target()
	timer.start(5.0)

func pick_new_target():
	var nearest_dist = 9999.0
	var nearest_pos = global_position
	
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
						
	if nearest_dist < 9999.0:
		target_position = nearest_pos
	else:
		var random_offset = Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
		target_position = global_position + random_offset
		
	nav_agent.target_position = target_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

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
