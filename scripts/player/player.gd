extends CharacterBody3D

signal on_death(id: int, team: Team.TeamId, weapon_path: String)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var team: Team.TeamId = Team.TeamId.NONE
@export var health: int = 100

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData
var current_weapon: WeaponData
var current_ammo: int = 0

var is_bot: bool = false
var bot_input_dir: Vector2 = Vector2.ZERO
var bot_wants_fire: bool = false
var bot_wants_interact: bool = false
var bot_wants_reload: bool = false
var bot_wants_walk: bool = false

var can_fire: bool = true
var is_reloading: bool = false
var has_bomb: bool = false
var is_dead: bool = false
var spectator_target: Node3D = null
var kill_cam_timer: float = 0.0
var killer_target: Node3D = null

var is_crouching: bool = false
var is_walking: bool = false
var is_ads: bool = false
var current_sens_mult: float = 1.0
var distance_moved: float = 0.0
var grenade_cooldown: bool = false
var grenade_script = preload("res://scripts/weapons/grenade.gd")

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var weapon_model = $Camera3D/WeaponModel
@onready var weapon_timer = $WeaponTimer
@onready var fire_sound = $Camera3D/WeaponModel/FireSound
@onready var footstep_audio = $FootstepAudio

var is_planting: bool = false
var is_defusing: bool = false
var current_plant_time: float = 0.0
var current_defuse_time: float = 0.0

# Recoil system
var recoil_target: Vector3 = Vector3.ZERO
var recoil_current: Vector3 = Vector3.ZERO
var shots_fired_in_burst: int = 0
var last_fire_time: float = 0.0
var current_spread: float = 0.0

# HUD reference
var hud_scene = preload("res://hud.tscn")
var hud_instance: CanvasLayer
var touch_scene = preload("res://touch_controls.tscn")
var touch_instance: CanvasLayer

# Head bobbing parameters
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0
var CAMERA_BASE_Y = 0.6
@onready var collision_shape = $CollisionShape3D
@onready var mesh_instance = $MeshInstance3D

func _enter_tree():
	add_to_group("Players")
	set_multiplayer_authority(name.to_int())
	
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var config = SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property("Camera3D:rotation")
	sync.replication_config = config
	add_child(sync)

func _ready():
	if not is_multiplayer_authority():
		if camera: camera.current = false
		return
		
	if camera: 
		camera.current = true
		print("Player spawned, camera active")
		
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()
		var mat = StandardMaterial3D.new()
		if team == Team.TeamId.POLICE:
			mat.albedo_color = Color(0.2, 0.4, 0.8) # Police Blue
		elif team == Team.TeamId.TERRORIST:
			mat.albedo_color = Color(0.8, 0.2, 0.2) # Terrorist Red
		mesh_instance.mesh.surface_set_material(0, mat)
		
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	hud_instance.local_player = self
	
	var loadout_ui = hud_instance.get_node_or_null("LoadoutUI")
	if loadout_ui:
		loadout_ui.local_player = self
	
	if OS.has_feature("mobile") or OS.has_feature("web"):
		touch_instance = touch_scene.instantiate()
		add_child(touch_instance)
		
	if primary_weapon:
		equip_weapon(primary_weapon)

func _input(event):
	if not is_multiplayer_authority() or is_bot: return
	
	if is_dead:
		if event.is_action_pressed("fire"):
			cycle_spectator()
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag and OS.has_feature("mobile"):
		# Right half of screen for look around
		if event.position.x > get_viewport().size.x / 2:
			_rotate_camera(event.relative * 0.5)

func _rotate_camera(relative: Vector2):
	rotate_y(-relative.x * 0.005 * current_sens_mult)
	camera.rotate_x(-relative.y * 0.005 * current_sens_mult)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	if is_dead:
		if kill_cam_timer > 0.0:
			kill_cam_timer -= delta
			if is_instance_valid(killer_target):
				var target_pos = killer_target.global_transform.origin + killer_target.global_transform.basis.z * 3.0 + Vector3.UP * 2.0
				camera.global_transform.origin = camera.global_transform.origin.lerp(target_pos, delta * 10.0)
				camera.look_at(killer_target.global_transform.origin + Vector3.UP * 1.5, Vector3.UP)
				
				if hud_instance:
					hud_instance.set_spectator_text("Kill Cam: " + killer_target.name, Color.RED)
			
			if kill_cam_timer <= 0.0:
				_find_spectator_target()
		else:
			if is_instance_valid(spectator_target) and not spectator_target.is_dead:
				camera.global_transform = spectator_target.camera.global_transform
				if hud_instance:
					var p_name = PlayerStats.stats[spectator_target.name.to_int()]["name"] if PlayerStats.stats.has(spectator_target.name.to_int()) else spectator_target.name
					hud_instance.set_spectator_text("Spectating: " + p_name, Color.WHITE)
			else:
				if hud_instance: hud_instance.set_spectator_text("Waiting for respawn...", Color.GRAY)
				_find_spectator_target()
		return
	
	if Time.get_ticks_msec() / 1000.0 - last_fire_time > 0.25:
		shots_fired_in_burst = 0
	
	if current_weapon:
		if shots_fired_in_burst <= 1:
			current_spread = current_weapon.spread * 0.1
		else:
			current_spread = current_weapon.spread * min(float(shots_fired_in_burst) / 5.0, 3.0)
			
	var target_fov = 75.0
	if not is_bot and Input.is_action_pressed("aim") and current_weapon and current_weapon.can_ads:
		is_ads = true
		target_fov = current_weapon.ads_fov
	else:
		is_ads = false
		
	camera.fov = lerp(camera.fov, target_fov, delta * 15.0)
	current_sens_mult = camera.fov / 75.0
	
	if is_ads and abs(camera.fov - target_fov) < 5.0:
		weapon_model.hide()
	else:
		weapon_model.show()
	
	# Handle Recoil Recovery
	recoil_target = recoil_target.lerp(Vector3.ZERO, delta * 8.0)
	recoil_current = recoil_current.lerp(recoil_target, delta * 15.0)
	camera.rotation_degrees.x += recoil_current.x
	camera.rotation_degrees.y += recoil_current.y

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Vector2.ZERO
	if not is_bot:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		is_crouching = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL)
		is_walking = Input.is_key_pressed(KEY_SHIFT)
	else:
		input_dir = bot_input_dir
		is_crouching = false
		is_walking = bot_wants_walk
		
	var target_height = 1.0 if is_crouching else 2.0
	var target_cam_y = 0.2 if is_crouching else 0.6
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	if mesh_instance and mesh_instance.mesh is CapsuleMesh:
		mesh_instance.mesh.height = lerp(mesh_instance.mesh.height, target_height, delta * 10.0)
	
	CAMERA_BASE_Y = lerp(CAMERA_BASE_Y, target_cam_y, delta * 10.0)
	
	var current_speed = SPEED * (0.5 if is_crouching or is_walking or is_ads else 1.0)
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	# Headbob & Footsteps logic
	if is_on_floor() and velocity.length() > 0.5:
		t_bob += delta * velocity.length()
		var pos = Vector3.ZERO
		pos.y = sin(t_bob * BOB_FREQ) * BOB_AMP + CAMERA_BASE_Y
		pos.x = cos(t_bob * BOB_FREQ / 2.0) * BOB_AMP
		camera.position = camera.position.lerp(pos, delta * 10.0)
		
		if not is_walking and not is_crouching:
			distance_moved += velocity.length() * delta
			if distance_moved > 2.5: # Emit footstep every 2.5 meters
				distance_moved = 0.0
				_emit_footstep()
	else:
		t_bob = 0.0
		camera.position = camera.position.lerp(Vector3(0, CAMERA_BASE_Y, 0), delta * 10.0)

func _emit_footstep():
	if MatchManager.is_offline_solo:
		_play_footstep()
	else:
		rpc("play_footstep_rpc")
		
@rpc("any_peer", "call_local", "unreliable")
func play_footstep_rpc():
	_play_footstep()

func _play_footstep():
	if footstep_audio:
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.play()
		
	# Bot Hearing System
	if multiplayer.is_server() or MatchManager.is_offline_solo:
		for bot in get_tree().get_nodes_in_group("Players"):
			if bot.is_bot and bot.team != team and bot.health > 0:
				if bot.global_position.distance_to(global_position) <= 15.0:
					# Alert bot
					var controller = bot.get_node_or_null("BotController")
					if controller:
						controller.hear_footstep(self)

	# Bomb interactions
	var bomb_progress = 0.0
	var is_interacting = false
	
	var active_site = null
	for site in get_tree().get_nodes_in_group("BombSite"):
		if site.is_active and site.is_player_inside and site.planting_player == self:
			active_site = site
			break
			
	var wants_interact = bot_wants_interact if is_bot else Input.is_action_pressed("use")
	if wants_interact:
		if active_site:
			if team == Team.TeamId.TERRORIST and has_bomb and not MatchManager.is_bomb_planted:
				if not is_planting: 
					is_planting = true
					current_plant_time = 0.0
					print("Started planting at Site ", active_site.site_name)
				current_plant_time += delta
				bomb_progress = current_plant_time / 3.5
				is_interacting = true
				if current_plant_time >= 3.5:
					MatchManager.plant_bomb(active_site.global_position)
					has_bomb = false
					is_planting = false
					print("Bomb Planted at Site ", active_site.site_name)
			elif team == Team.TeamId.POLICE and MatchManager.is_bomb_planted:
				if not is_defusing:
					is_defusing = true
					current_defuse_time = 0.0
					print("Started defusing at Site ", active_site.site_name)
				current_defuse_time += delta
				
				var p_id = name.to_int()
				var defuse_duration = 2.5 if PlayerStats.stats.has(p_id) and PlayerStats.stats[p_id].get("has_defuse_kit", false) else 5.0
				
				bomb_progress = current_defuse_time / defuse_duration
				is_interacting = true
				if current_defuse_time >= defuse_duration:
					MatchManager.defuse_bomb()
					is_defusing = false
					print("Bomb Defused at Site ", active_site.site_name)
	else:
		if is_planting or is_defusing:
			is_planting = false
			is_defusing = false
			current_plant_time = 0.0
			current_defuse_time = 0.0
			print("Bomb interaction canceled.")

	var wants_fire = bot_wants_fire if is_bot else Input.is_action_pressed("fire")
	if wants_fire and can_fire and not is_reloading and current_weapon and not is_interacting:
		if current_ammo > 0:
			fire_weapon()
		else:
			reload_weapon()
			
	var wants_reload = bot_wants_reload if is_bot else Input.is_action_just_pressed("reload")
	if wants_reload and not is_reloading and not is_interacting:
		reload_weapon()
		
	if not is_bot:
		if Input.is_action_just_pressed("switch_weapon_1") and primary_weapon:
			equip_weapon(primary_weapon)
		elif Input.is_action_just_pressed("switch_weapon_2") and secondary_weapon:
			equip_weapon(secondary_weapon)
		
		if Input.is_key_pressed(KEY_G) and not grenade_cooldown:
			var p_id = name.to_int()
			var want_smoke = Input.is_key_pressed(KEY_SHIFT)
			if want_smoke:
				var s_count = PlayerStats.stats[p_id].get("smoke_count", 0) if PlayerStats.stats.has(p_id) else 0
				if s_count > 0:
					grenade_cooldown = true
					PlayerStats.stats[p_id]["smoke_count"] = s_count - 1
					PlayerStats.sync_all_stats()
					_throw_grenade(true)
					get_tree().create_timer(1.0).timeout.connect(func(): grenade_cooldown = false)
			else:
				var g_count = PlayerStats.stats[p_id].get("grenade_count", 0) if PlayerStats.stats.has(p_id) else 0
				if g_count > 0:
					grenade_cooldown = true
					PlayerStats.stats[p_id]["grenade_count"] = g_count - 1
					PlayerStats.sync_all_stats()
					_throw_grenade(false)
					get_tree().create_timer(1.0).timeout.connect(func(): grenade_cooldown = false)
		
	_update_hud(is_interacting, bomb_progress)

func _throw_grenade(smoke: bool = false):
	if MatchManager.is_offline_solo:
		request_throw_grenade(camera.global_transform.origin, -camera.global_transform.basis.z, velocity, smoke)
	else:
		rpc_id(1, "request_throw_grenade", camera.global_transform.origin, -camera.global_transform.basis.z, velocity, smoke)

@rpc("any_peer", "call_local", "reliable")
func request_throw_grenade(origin: Vector3, direction: Vector3, thrower_vel: Vector3, smoke: bool = false):
	if not MatchManager.is_offline_solo and not multiplayer.is_server(): return
	
	var thrower_id = get_multiplayer_authority() if MatchManager.is_offline_solo else multiplayer.get_remote_sender_id()
	
	var grenade = grenade_script.new()
	grenade.thrower_id = thrower_id
	grenade.thrower_team = team
	grenade.is_smoke = smoke
	grenade.position = origin + direction * 1.5
	grenade.linear_velocity = thrower_vel + direction * 15.0
	
	get_tree().root.add_child(grenade, true)

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
	
	shots_fired_in_burst += 1
	last_fire_time = Time.get_ticks_msec() / 1000.0
	
	# Apply Recoil
	var kick = Vector2(randf_range(0.5, 1.5), randf_range(-0.5, 0.5))
	if current_weapon.recoil_pattern and current_weapon.recoil_pattern.size() > 0:
		var idx = clampi(shots_fired_in_burst - 1, 0, current_weapon.recoil_pattern.size() - 1)
		kick = current_weapon.recoil_pattern[idx]
		# Add a tiny bit of random jitter to the deterministic pattern
		kick += Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		
	recoil_target += Vector3(kick.x, kick.y, 0)
	
	# Weapon Animation (Kickback)
	var tween = create_tween()
	weapon_model.position.z += 0.1
	tween.tween_property(weapon_model, "position:z", weapon_model.position.z - 0.1, 0.1)
	
	if fire_sound:
		fire_sound.play()
		
	# Minimap Radar Ping (Offline Solo bots)
	if MatchManager.is_offline_solo and is_bot:
		for p in get_tree().get_nodes_in_group("Players"):
			if p.is_multiplayer_authority() and not p.is_bot:
				if p.hud_instance and p.hud_instance.has_method("add_radar_ping"):
					p.hud_instance.add_radar_ping(team, global_position)
				break
	
	# Hit detection locally for instant feedback
	if raycast.is_colliding():
		var target = raycast.get_collider()
		# We could show impact particles here
	
	var base_dir = -camera.global_transform.basis.z * current_weapon.range
	var directions = []
	var spread_mult = 0.5 if is_crouching else 1.0
	for i in range(current_weapon.pellet_count):
		var spread_x = randf_range(-current_spread * spread_mult, current_spread * spread_mult)
		var spread_y = randf_range(-current_spread * spread_mult, current_spread * spread_mult)
		var spread_dir = (base_dir + camera.global_transform.basis.x * spread_x * current_weapon.range + camera.global_transform.basis.y * spread_y * current_weapon.range)
		directions.append(spread_dir)
	
	if MatchManager.is_offline_solo:
		request_fire(camera.global_transform.origin, directions)
	else:
		rpc_id(1, "request_fire", camera.global_transform.origin, directions)
		rpc("sync_shoot_effects")

@rpc("any_peer", "call_remote", "unreliable")
func sync_shoot_effects():
	# Play sound and animation on remote clients
	var tween = create_tween()
	weapon_model.position.z += 0.1
	tween.tween_property(weapon_model, "position:z", weapon_model.position.z - 0.1, 0.1)
	
	if fire_sound:
		fire_sound.play()
		
	# Minimap Radar Ping (Multiplayer remote clients)
	for p in get_tree().get_nodes_in_group("Players"):
		if p.is_multiplayer_authority():
			if p.hud_instance and p.hud_instance.has_method("add_radar_ping"):
				p.hud_instance.add_radar_ping(team, global_position)
			break

@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, directions: Array):
	if not MatchManager.is_offline_solo and not multiplayer.is_server(): return
	if not MatchManager.is_offline_solo and multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return
	
	var space_state = get_world_3d().direct_space_state
	for dir in directions:
		var query = PhysicsRayQueryParameters3D.create(origin, origin + dir)
		query.exclude = [self]
		
		var end_pos = origin + dir
		var did_hit_player = false
		var hit_normal = Vector3.ZERO
		var result = space_state.intersect_ray(query)
		if result:
			end_pos = result.position
			hit_normal = result.normal
			var target = result.collider
			if target.has_method("take_damage"):
				var did_hit = target.take_damage(current_weapon.damage, team, get_multiplayer_authority())
				if did_hit:
					did_hit_player = true
					if MatchManager.is_offline_solo:
						show_hitmarker()
					else:
						rpc_id(get_multiplayer_authority(), "show_hitmarker")
		
		if MatchManager.is_offline_solo:
					sync_tracer(origin, end_pos, hit_normal, did_hit_player)
		else:
			rpc("sync_tracer", origin, end_pos, hit_normal, did_hit_player)

@rpc("any_peer", "call_local", "unreliable")
func sync_tracer(start_pos: Vector3, end_pos: Vector3, hit_normal: Vector3, hit_player: bool):
	if start_pos.distance_to(end_pos) < 0.1: return
	
	# TRACER
	var tracer = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = start_pos.distance_to(end_pos)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0
	mesh.surface_set_material(0, mat)
	tracer.mesh = mesh
	
	get_tree().root.add_child(tracer)
	tracer.global_position = (start_pos + end_pos) / 2.0
	tracer.look_at(end_pos, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI/2.0)
	
	var tween = create_tween()
	tween.tween_property(tracer, "transparency", 1.0, 0.15)
	tween.tween_callback(tracer.queue_free)
	
	# DECAL
	if hit_normal != Vector3.ZERO:
		var decal = MeshInstance3D.new()
		var qmesh = QuadMesh.new()
		qmesh.size = Vector2(0.25, 0.25) if hit_player else Vector2(0.12, 0.12)
		
		var dmat = StandardMaterial3D.new()
		dmat.albedo_color = Color(0.6, 0.0, 0.0) if hit_player else Color(0.1, 0.1, 0.1)
		
		qmesh.surface_set_material(0, dmat)
		decal.mesh = qmesh
		get_tree().root.add_child(decal)
		
		decal.global_position = end_pos + hit_normal * 0.01
		
		if hit_normal.is_equal_approx(Vector3.UP) or hit_normal.is_equal_approx(Vector3.DOWN):
			decal.look_at(decal.global_position + hit_normal, Vector3.RIGHT)
		else:
			decal.look_at(decal.global_position + hit_normal, Vector3.UP)
			
		var dtween = create_tween()
		dtween.tween_interval(8.0)
		dtween.tween_property(decal, "transparency", 1.0, 2.0)
		dtween.tween_callback(decal.queue_free)
	
	# BLOOD SPLATTER
	if hit_player:
		var blood = CPUParticles3D.new()
		blood.emitting = false
		blood.one_shot = true
		blood.explosiveness = 1.0
		blood.amount = 16
		blood.lifetime = 0.5
		
		var bmesh = BoxMesh.new()
		bmesh.size = Vector3(0.08, 0.08, 0.08)
		var bmat = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.6, 0.0, 0.0)
		bmesh.surface_set_material(0, bmat)
		blood.mesh = bmesh
		
		blood.direction = (start_pos - end_pos).normalized()
		blood.spread = 45.0
		blood.initial_velocity_min = 2.0
		blood.initial_velocity_max = 5.0
		
		get_tree().root.add_child(blood)
		blood.global_position = end_pos
		blood.emitting = true
		
		get_tree().create_timer(1.0).timeout.connect(blood.queue_free)

@rpc("authority", "call_local", "unreliable")
func show_hitmarker():
	if hud_instance and hud_instance.has_method("show_hitmarker"):
		hud_instance.show_hitmarker()

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

func take_damage(amount: int, attacker_team: Team.TeamId, attacker_id: int = 1) -> bool:
	if not multiplayer.is_server(): return false
	if attacker_team == team: return false
		
	var actual_damage = amount
	var p_id = name.to_int()
	if PlayerStats.stats.has(p_id) and PlayerStats.stats[p_id].get("has_armor", false):
		actual_damage = amount / 2
		
	health -= actual_damage
	rpc("sync_health", health)
	
	if health <= 0:
		die(attacker_id)
		
	return true

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: int):
	health = new_health

func die(attacker_id: int):
	if not multiplayer.is_server(): return
	var p_id = name.to_int()
	PlayerStats.record_kill_event(attacker_id, p_id, current_weapon.weapon_name if current_weapon else "Unknown")
	
	if PlayerStats.stats.has(p_id):
		PlayerStats.stats[p_id]["has_armor"] = false
		PlayerStats.stats[p_id]["has_defuse_kit"] = false
		PlayerStats.sync_all_stats()
		
	emit_signal("on_death", p_id, team, primary_weapon.resource_path if primary_weapon else "")
	rpc("sync_death", attacker_id)
	
	if MatchManager.match_size == MatchManager.MatchSize.SOLO:
		queue_free()

@rpc("authority", "call_local", "reliable")
func sync_death(killer_id: int = -1):
	is_dead = true
	health = 0
	collision_shape.disabled = true
	mesh_instance.hide()
	weapon_model.hide()
	
	if is_multiplayer_authority():
		if hud_instance: hud_instance.hide_crosshair_and_scope()
		
		# Set up Kill Cam
		killer_target = get_tree().root.get_node_or_null("Level/PlayersContainer/" + str(killer_id))
		if is_instance_valid(killer_target):
			kill_cam_timer = 3.0
			# Initial snap slightly behind
			camera.global_transform.origin = killer_target.global_transform.origin + killer_target.global_transform.basis.z * 3.0 + Vector3.UP * 2.0
		else:
			_find_spectator_target()
		
	if MatchManager.match_size == MatchManager.MatchSize.SOLO and not multiplayer.is_server():
		queue_free()

func _find_spectator_target():
	spectator_target = null
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if p != self and not p.is_dead and p.team == team:
			spectator_target = p
			break

func cycle_spectator():
	var players = get_tree().get_nodes_in_group("Players")
	var valid = []
	for p in players:
		if p != self and not p.is_dead and p.team == team:
			valid.append(p)
			
	if valid.is_empty():
		spectator_target = null
		return
		
	if not spectator_target in valid:
		spectator_target = valid[0]
	else:
		var idx = valid.find(spectator_target)
		idx = (idx + 1) % valid.size()
		spectator_target = valid[idx]

