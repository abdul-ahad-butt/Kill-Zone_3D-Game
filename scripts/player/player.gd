extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var team: Team.TeamId = Team.TeamId.NONE
@export var health: int = 100

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData
var current_weapon: WeaponData

var can_fire: bool = true
var is_reloading: bool = false
var has_bomb: bool = false

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var weapon_timer = $WeaponTimer

func _enter_tree():
	# Name the node to the peer_id before it enters the tree for MultiplayerSpawner
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		# Disable camera for other players
		if camera: camera.current = false
		return
		
	if camera: camera.current = true
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if primary_weapon:
		equip_weapon(primary_weapon)

func _input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)

func _rotate_camera(relative: Vector2):
	rotate_y(-relative.x * 0.005)
	camera.rotate_x(-relative.y * 0.005)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	if Input.is_action_pressed("fire") and can_fire and not is_reloading and current_weapon:
		fire_weapon()
		
	if Input.is_action_just_pressed("switch_weapon_1") and primary_weapon:
		equip_weapon(primary_weapon)
	elif Input.is_action_just_pressed("switch_weapon_2") and secondary_weapon:
		equip_weapon(secondary_weapon)

func equip_weapon(weapon: WeaponData):
	current_weapon = weapon
	if raycast:
		raycast.target_position = Vector3(0, 0, -current_weapon.range)

func fire_weapon():
	can_fire = false
	weapon_timer.start(current_weapon.fire_rate)
	
	# Local visual feedback
	# Play muzzle flash / sound here immediately
	
	# Send request to server
	rpc_id(1, "request_fire", camera.global_transform.origin, -camera.global_transform.basis.z * current_weapon.range)

@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, direction: Vector3):
	# Only the server should process hit detection
	if not multiplayer.is_server(): return
	
	# Security check: Ensure the sender is the actual player
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return
	
	# Server performs its own raycast or uses the provided vectors
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		var target = result.collider
		if target.has_method("take_damage"):
			target.take_damage(current_weapon.damage, team, get_multiplayer_authority())

func _on_weapon_timer_timeout():
	can_fire = true

func take_damage(amount: int, attacker_team: Team.TeamId, attacker_id: int = 1):
	if not multiplayer.is_server(): return
	if attacker_team == team: return # Friendly fire off
		
	health -= amount
	rpc("sync_health", health)
	
	if health <= 0:
		die(attacker_id)

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: int):
	health = new_health
	if health <= 0 and not multiplayer.is_server():
		pass # Client side death effects

func die(attacker_id: int):
	if not multiplayer.is_server(): return
	print("Player ", name, " on team ", team, " died!")
	
	PlayerStats.record_kill_event(attacker_id, name.to_int(), current_weapon.weapon_name if current_weapon else "Unknown")
	
	if has_bomb:
		pass # Logic to drop bomb
	
	rpc("sync_death")
	queue_free()

@rpc("authority", "call_remote", "reliable")
func sync_death():
	queue_free()
