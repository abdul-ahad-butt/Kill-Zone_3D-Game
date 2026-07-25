extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var team: Team.TeamId = Team.TeamId.NONE
@export var health: int = 100

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData
var current_weapon: WeaponData
var current_viewmodel: Node3D
var _recoil_tween: Tween

var can_fire: bool = true
var is_reloading: bool = false
var has_bomb: bool = false

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var weapon_timer = $WeaponTimer

var gunshot_audio: AudioStreamPlayer3D
var footstep_audio: AudioStreamPlayer3D

func _enter_tree():
	# Name the node to the peer_id before it enters the tree for MultiplayerSpawner
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		# Disable camera for other players
		if camera: camera.current = false
		return
		
	if camera: camera.current = true
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if primary_weapon:
		equip_weapon(primary_weapon)
		
	var soldier = load("res://scenes/player/tactical_soldier.tscn").instantiate()
	soldier.team = team
	soldier.name = "TacticalSoldier"
	add_child(soldier)
	if is_multiplayer_authority():
		soldier.visible = false
		
	# Setup Audio
	gunshot_audio = AudioStreamPlayer3D.new()
	add_child(gunshot_audio)
	
	footstep_audio = AudioStreamPlayer3D.new()
	add_child(footstep_audio)

func _input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag:
		# Only rotate if the drag is on the right half of the screen
		if event.position.x > get_viewport().size.x / 2.0:
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
		if is_on_floor() and footstep_audio and not footstep_audio.playing:
			var am = get_node_or_null("/root/AudioManager")
			if am:
				footstep_audio.stream = am.footstep_sound
				footstep_audio.play()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	var is_ads = false
	if Input.is_action_pressed("ads") and current_weapon:
		is_ads = true
		camera.fov = lerp(camera.fov, current_weapon.ads_fov, delta * 15.0)
		if current_viewmodel:
			current_viewmodel.position = current_viewmodel.position.lerp(current_weapon.ads_position, delta * 15.0)
	else:
		camera.fov = lerp(camera.fov, 75.0, delta * 15.0)
		if current_viewmodel and current_weapon:
			current_viewmodel.position = current_viewmodel.position.lerp(current_weapon.default_position, delta * 10.0)
			
	if Input.is_action_just_pressed("reload") and current_weapon and not is_reloading:
		_start_reload()

	if Input.is_action_pressed("fire") and can_fire and not is_reloading and current_weapon:
		fire_weapon()
		
	if Input.is_action_just_pressed("switch_weapon_1") and primary_weapon:
		equip_weapon(primary_weapon)
	elif Input.is_action_just_pressed("switch_weapon_2") and secondary_weapon:
		equip_weapon(secondary_weapon)

func _start_reload():
	is_reloading = true
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_2d(am.reload_sound)
	await get_tree().create_timer(current_weapon.reload_time).timeout
	is_reloading = false

func equip_weapon(weapon: WeaponData):
	if current_weapon == weapon: return
	current_weapon = weapon
	if raycast:
		raycast.target_position = Vector3(0, 0, -current_weapon.range)
	
	if current_viewmodel:
		current_viewmodel.queue_free()
		
	if weapon.model_scene:
		current_viewmodel = weapon.model_scene.instantiate()
		camera.add_child(current_viewmodel)
		current_viewmodel.position = weapon.default_position

func fire_weapon():
	can_fire = false
	weapon_timer.start(current_weapon.fire_rate)
	
	if current_viewmodel:
		if _recoil_tween and _recoil_tween.is_running():
			_recoil_tween.kill()
		_recoil_tween = create_tween()
		var original_pos = current_viewmodel.position
		
		# Apply recoil kick
		current_viewmodel.position.z += current_weapon.recoil_kick
		current_viewmodel.rotation.x += current_weapon.recoil_kick * 0.5
		
		_recoil_tween.set_parallel(true)
		var target_pos = current_weapon.ads_position if Input.is_action_pressed("ads") else current_weapon.default_position
		_recoil_tween.tween_property(current_viewmodel, "position", target_pos, 0.1).set_ease(Tween.EASE_OUT)
		_recoil_tween.tween_property(current_viewmodel, "rotation:x", 0.0, 0.1).set_ease(Tween.EASE_OUT)
		
		# Trigger particles
		var flash = current_viewmodel.get_node_or_null("MuzzleFlash")
		if flash and flash is GPUParticles3D:
			flash.restart()
			
		var light = current_viewmodel.get_node_or_null("MuzzleLight")
		if light and light is OmniLight3D:
			light.visible = true
			var t = create_tween()
			t.tween_property(light, "visible", false, 0.05).set_delay(0.05)
			
	if gunshot_audio:
		var am = get_node_or_null("/root/AudioManager")
		if am: gunshot_audio.stream = am.gunshot_sound
		gunshot_audio.play()
	
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
	if NetworkManager.is_team_mode and attacker_team == team: return # Friendly fire off in team mode
		
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
