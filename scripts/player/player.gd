extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var team: Team.TeamId = Team.TeamId.NONE
@export var health: int = 100

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData
var current_weapon: WeaponData
var current_ammo: int = 0

var can_fire: bool = true
var is_reloading: bool = false
var has_bomb: bool = false

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var weapon_model = $Camera3D/WeaponModel
@onready var weapon_timer = $WeaponTimer

# Recoil system
var recoil_target: Vector3 = Vector3.ZERO
var recoil_current: Vector3 = Vector3.ZERO

# HUD reference
var hud_scene = preload("res://hud.tscn")
var hud_instance: CanvasLayer
var touch_scene = preload("res://touch_controls.tscn")
var touch_instance: CanvasLayer

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		if camera: camera.current = false
		return
		
	if camera: camera.current = true
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	
	if OS.has_feature("mobile") or OS.has_feature("web"):
		touch_instance = touch_scene.instantiate()
		add_child(touch_instance)
		
	if primary_weapon:
		equip_weapon(primary_weapon)

func _input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag and OS.has_feature("mobile"):
		# Right half of screen for look around
		if event.position.x > get_viewport().size.x / 2:
			_rotate_camera(event.relative * 0.5)

func _rotate_camera(relative: Vector2):
	rotate_y(-relative.x * 0.005)
	camera.rotate_x(-relative.y * 0.005)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Handle Recoil Recovery
	recoil_target = recoil_target.lerp(Vector3.ZERO, delta * 8.0)
	recoil_current = recoil_current.lerp(recoil_target, delta * 15.0)
	camera.rotation_degrees.x += recoil_current.x
	camera.rotation_degrees.y += recoil_current.y

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

	# Bomb interactions
	var bomb_progress = 0.0
	var is_interacting = false
	var bomb_node = get_tree().root.get_node_or_null("Node3D/Bomb") # Example global path or you'd search it
	if not bomb_node:
		bomb_node = get_node_or_null("Bomb") # As child
	
	if Input.is_action_pressed("use"):
		if bomb_node and bomb_node.has_method("start_planting"):
			# In a real setup, we'd ensure player is inside a BombSite
			if team == Team.TeamId.TERRORIST and has_bomb and not MatchManager.is_bomb_planted:
				if not bomb_node.is_planting: bomb_node.start_planting(self)
				is_interacting = bomb_node.is_planting
				bomb_progress = bomb_node.current_plant_time / bomb_node.plant_time_required
			elif team == Team.TeamId.POLICE and MatchManager.is_bomb_planted:
				if not bomb_node.is_defusing: bomb_node.start_defusing(self)
				is_interacting = bomb_node.is_defusing
				bomb_progress = bomb_node.current_defuse_time / bomb_node.defuse_time_required
	else:
		if bomb_node and (bomb_node.is_planting or bomb_node.is_defusing) and bomb_node.interacting_player == self:
			bomb_node.cancel_interaction()

	if Input.is_action_pressed("fire") and can_fire and not is_reloading and current_weapon and not is_interacting:
		if current_ammo > 0:
			fire_weapon()
		else:
			reload_weapon()
			
	if Input.is_action_just_pressed("reload") and not is_reloading and not is_interacting:
		reload_weapon()
		
	if Input.is_action_just_pressed("switch_weapon_1") and primary_weapon:
		equip_weapon(primary_weapon)
	elif Input.is_action_just_pressed("switch_weapon_2") and secondary_weapon:
		equip_weapon(secondary_weapon)
		
	_update_hud(is_interacting, bomb_progress)

func equip_weapon(weapon: WeaponData):
	current_weapon = weapon
	current_ammo = current_weapon.mag_size
	is_reloading = false
	can_fire = true
	if raycast:
		raycast.target_position = Vector3(0, 0, -current_weapon.range)

func reload_weapon():
	if current_weapon and current_ammo < current_weapon.mag_size:
		is_reloading = true
		await get_tree().create_timer(current_weapon.reload_time).timeout
		current_ammo = current_weapon.mag_size
		is_reloading = false

func fire_weapon():
	can_fire = false
	current_ammo -= 1
	weapon_timer.start(current_weapon.fire_rate)
	
	# Apply Recoil
	recoil_target += Vector3(randf_range(0.5, 1.5), randf_range(-0.5, 0.5), 0)
	
	# Weapon Animation (Kickback)
	var tween = create_tween()
	weapon_model.position.z += 0.1
	tween.tween_property(weapon_model, "position:z", weapon_model.position.z - 0.1, 0.1)
	
	# Hit detection locally for instant feedback
	if raycast.is_colliding():
		var target = raycast.get_collider()
		# We could show impact particles here
	
	rpc_id(1, "request_fire", camera.global_transform.origin, -camera.global_transform.basis.z * current_weapon.range)

@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, direction: Vector3):
	if not multiplayer.is_server(): return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return
	
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

func _update_hud(is_interacting: bool = false, bomb_progress: float = 0.0):
	if hud_instance:
		var ammo_label = hud_instance.get_node_or_null("AmmoLabel")
		if ammo_label and current_weapon:
			if is_reloading:
				ammo_label.text = "Reloading..."
			else:
				ammo_label.text = str(current_ammo) + " / " + str(current_weapon.mag_size)
				
		var bomb_progress_bar = hud_instance.get_node_or_null("BombProgress")
		if bomb_progress_bar:
			if is_interacting:
				bomb_progress_bar.show()
				bomb_progress_bar.value = bomb_progress * 100
			else:
				bomb_progress_bar.hide()

func take_damage(amount: int, attacker_team: Team.TeamId, attacker_id: int = 1):
	if not multiplayer.is_server(): return
	if attacker_team == team: return
		
	health -= amount
	rpc("sync_health", health)
	
	if health <= 0:
		die(attacker_id)

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: int):
	health = new_health

func die(attacker_id: int):
	if not multiplayer.is_server(): return
	PlayerStats.record_kill_event(attacker_id, name.to_int(), current_weapon.weapon_name if current_weapon else "Unknown")
	rpc("sync_death")
	queue_free()

@rpc("authority", "call_remote", "reliable")
func sync_death():
	queue_free()

