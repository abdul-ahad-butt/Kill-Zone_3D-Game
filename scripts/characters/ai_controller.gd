extends BaseCharacter
class_name AIController

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_raycast: RayCast3D = RayCast3D.new()

enum AIState {
	PATROL,
	INVESTIGATE,
	COMBAT,
	FLEE
}

var current_state: AIState = AIState.PATROL
var target_position: Vector3
var target_enemy: BaseCharacter

var patrol_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0

var vision_range: float = 30.0
var fov_angle: float = 70.0

var weapon_controller # Reference to weapon

func _ready():
	super._ready()
	add_to_group("ai")
	
	# Setup vision raycast
	add_child(vision_raycast)
	vision_raycast.position = Vector3(0, 1.5, 0) # Eye level
	vision_raycast.target_position = Vector3(0, 0, -vision_range)
	
	# Try to find a weapon controller if it exists
	if has_node("WeaponController"):
		weapon_controller = get_node("WeaponController")

func _physics_process(delta):
	if not multiplayer.is_server(): return
	if current_health <= 0: return

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	_update_perception()

	match current_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.INVESTIGATE:
			_process_investigate(delta)
		AIState.COMBAT:
			_process_combat(delta)
		AIState.FLEE:
			_process_flee(delta)
			
	move_and_slide()

func _update_perception():
	# Simple vision check
	if target_enemy == null or current_state != AIState.COMBAT:
		var players = get_tree().get_nodes_in_group("players")
		var ai_chars = get_tree().get_nodes_in_group("ai")
		var all_chars = players + ai_chars
		
		for potential_target in all_chars:
			if potential_target == self or not potential_target is BaseCharacter: continue
			
			if potential_target.faction != self.faction and potential_target.faction != Faction.NONE:
				var dir_to_target = (potential_target.global_position - global_position).normalized()
				var angle = rad_to_deg(global_transform.basis.z.angle_to(-dir_to_target))
				
				if angle < fov_angle / 2.0 and global_position.distance_to(potential_target.global_position) <= vision_range:
					vision_raycast.target_position = vision_raycast.to_local(potential_target.global_position + Vector3(0, 1, 0))
					vision_raycast.force_raycast_update()
					if vision_raycast.is_colliding() and vision_raycast.get_collider() == potential_target:
						target_enemy = potential_target
						current_state = AIState.COMBAT
						break

func _process_patrol(_delta):
	if patrol_waypoints.size() > 0:
		if nav_agent.is_navigation_finished():
			current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()
			nav_agent.set_target_position(patrol_waypoints[current_waypoint_index])
		else:
			_move_towards(nav_agent.get_next_path_position())

func _process_investigate(_delta):
	if not nav_agent.is_navigation_finished():
		_move_towards(nav_agent.get_next_path_position())
	else:
		current_state = AIState.PATROL

func _process_combat(delta):
	if target_enemy == null or target_enemy.current_health <= 0:
		target_enemy = null
		current_state = AIState.PATROL
		return
		
	# Face target
	var dir_to_target = (target_enemy.global_position - global_position)
	dir_to_target.y = 0
	if dir_to_target.length_squared() > 0.1:
		var target_rotation = atan2(dir_to_target.x, dir_to_target.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)
		
	# Try to fire
	if weapon_controller:
		weapon_controller.fire(false, false)

func _process_flee(_delta):
	# Move away from target_enemy if exists
	pass

func _move_towards(target_pos: Vector3):
	var direction = global_position.direction_to(target_pos)
	direction.y = 0
	velocity.x = direction.x * 3.0
	velocity.z = direction.z * 3.0
	
	if direction.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.1)

func hear_noise(location: Vector3):
	if current_state == AIState.PATROL:
		current_state = AIState.INVESTIGATE
		nav_agent.set_target_position(location)
