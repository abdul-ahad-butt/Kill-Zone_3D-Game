extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var team: Team.TeamId = Team.TeamId.NONE
@export var health: int = 100
@export var armor: int = 0
@export var has_defuse_kit: bool = false
@export var is_bot: bool = false

var bot_wants_fire: bool = false
var bot_wants_walk: bool = false
var bot_input_dir: Vector2 = Vector2.ZERO
var bot_wants_reload: bool = false
var bot_wants_interact: bool = false

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData
var melee_weapon: WeaponData
var current_weapon: WeaponData
var current_viewmodel: Node3D
var _recoil_tween: Tween

var current_ammo: int = 0
var reserve_ammo: int = 90

var can_fire: bool = true
var is_reloading: bool = false
var has_bomb: bool = false
var is_crouching: bool = false
var grenades_count: int = 2
var hud_spread: float = 0.0

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var weapon_timer = $WeaponTimer

var gunshot_audio: AudioStreamPlayer3D
var footstep_audio: AudioStreamPlayer3D

func _enter_tree():
	# Name the node to the peer_id before it enters the tree for MultiplayerSpawner
	set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("players")
	if not is_multiplayer_authority() and not is_bot:
		# Disable camera for other players
		if camera: camera.current = false
		return
		
	if is_bot and camera:
		camera.current = false
		
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
	
	if is_multiplayer_authority():
		var bm_scene = load("res://scenes/ui/buy_menu.tscn")
		if bm_scene:
			var bm = bm_scene.instantiate()
			bm.name = "BuyMenu"
			camera.add_child(bm)
			
		var sm_scene = load("res://scenes/ui/settings_menu.tscn")
		if sm_scene:
			var sm = sm_scene.instantiate()
			sm.name = "SettingsMenu"
			camera.add_child(sm)

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

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("buy_menu"):
		var buy_menu = get_node_or_null("Camera3D/BuyMenu")
		if buy_menu:
			if buy_menu.visible:
				buy_menu.close_menu()
			else:
				buy_menu.open_menu()
				
	if event.is_action_pressed("ui_cancel"):
		var settings_menu = get_node_or_null("Camera3D/SettingsMenu")
		if settings_menu:
			if settings_menu.visible:
				settings_menu.close_menu()
			else:
				settings_menu.open_menu()

var is_interacting = false
var interact_timer = 0.0
var previous_y_velocity = 0.0

func _process(delta):
	if not is_multiplayer_authority(): return
	if MatchManager.current_state != MatchManager.MatchState.LIVE: return
	
	if Input.is_action_pressed("use"):
		_handle_interaction(delta)
	elif is_interacting:
		_cancel_interaction()

func _handle_interaction(delta):
	if velocity.length() > 0.1 or health <= 0:
		_cancel_interaction()
		return
		
	if team == Team.TeamId.TERRORIST and not MatchManager.is_bomb_planted:
		var siteA = get_node_or_null("/root/World/BombSites/SiteA")
		var siteB = get_node_or_null("/root/World/BombSites/SiteB")
		var in_site = false
		if siteA and global_position.distance_to(siteA.global_position) < 8.0: in_site = true
		if siteB and global_position.distance_to(siteB.global_position) < 8.0: in_site = true
		
		if in_site:
			is_interacting = true
			interact_timer += delta
			if get_node_or_null("HUD"): get_node("HUD").show_interact_progress(interact_timer / 3.5, "Planting Bomb...")
			
			if interact_timer >= 3.5:
				_finish_plant()
				
	elif team == Team.TeamId.POLICE and MatchManager.is_bomb_planted:
		var bomb = get_tree().get_first_node_in_group("bomb")
		if bomb and global_position.distance_to(bomb.global_position) < 3.0:
			is_interacting = true
			interact_timer += delta
			if get_node_or_null("HUD"): get_node("HUD").show_interact_progress(interact_timer / 5.0, "Defusing Bomb...")
			
			if interact_timer >= 5.0:
				_finish_defuse()

func _cancel_interaction():
	is_interacting = false
	interact_timer = 0.0
	if get_node_or_null("HUD"): get_node("HUD").hide_interact_progress()

func _finish_plant():
	_cancel_interaction()
	rpc_id(1, "server_plant_bomb", global_position)

func _finish_defuse():
	_cancel_interaction()
	rpc_id(1, "server_defuse_bomb")

@rpc("any_peer", "call_local", "reliable")
func server_plant_bomb(pos: Vector3):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	
	if not MatchManager.is_bomb_planted:
		MatchManager.plant_bomb(sender)
		var b_scene = load("res://bomb.tscn")
		var b = b_scene.instantiate()
		b.add_to_group("bomb")
		b.global_position = pos
		get_node("/root/World").add_child(b)

@rpc("any_peer", "call_local", "reliable")
func server_defuse_bomb():
	if not multiplayer.is_server(): return
	if MatchManager.is_bomb_planted:
		var sender = multiplayer.get_remote_sender_id()
		MatchManager.defuse_bomb(sender)

func _physics_process(delta):
	if not is_multiplayer_authority() and not is_bot: return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var speed = Vector2(velocity.x, velocity.z).length()
	var target_spread = 2.0
	if not is_on_floor():
		target_spread = 40.0
	elif speed > 1.0:
		target_spread = 15.0
	if _recoil_tween and _recoil_tween.is_running():
		target_spread += 20.0
		
	var ads_pressed = Input.is_action_pressed("ads") if not is_bot else false
	if ads_pressed:
		target_spread *= 0.25
		
	var hud = get_node_or_null("HUD")
	if hud:
		hud.current_spread = lerp(hud.current_spread, target_spread, delta * 15.0)

	var jump_pressed = Input.is_action_just_pressed("jump") if not is_bot else false
	if jump_pressed and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
		
	is_crouching = Input.is_action_pressed("crouch") if not is_bot else false
	
	var current_speed = SPEED * 0.5 if is_crouching else SPEED
	if camera: camera.position.y = lerp(camera.position.y, 1.0 if is_crouching else 1.6, delta * 10.0)

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if is_bot: input_dir = bot_input_dir
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if is_on_floor() and footstep_audio and not footstep_audio.playing:
			var am = get_node_or_null("/root/AudioManager")
			if am:
				footstep_audio.stream = am.footstep_sound
				footstep_audio.play()
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	var was_on_floor = is_on_floor()
	move_and_slide()
	
	if not was_on_floor and is_on_floor():
		if previous_y_velocity < -12.0:
			var fall_damage = int((abs(previous_y_velocity) - 12.0) * 8.0)
			if fall_damage > 0:
				take_damage(fall_damage, team, name.to_int(), "Fall")
				
	if not is_on_floor():
		previous_y_velocity = velocity.y

	var is_ads = false
	if ads_pressed and current_weapon:
		is_ads = true
		if camera: camera.fov = lerp(camera.fov, current_weapon.ads_fov, delta * 15.0)
		if current_viewmodel:
			current_viewmodel.position = current_viewmodel.position.lerp(current_weapon.ads_position, delta * 15.0)
	else:
		if camera: camera.fov = lerp(camera.fov, 75.0, delta * 15.0)
		if current_viewmodel and current_weapon:
			current_viewmodel.position = current_viewmodel.position.lerp(current_weapon.default_position, delta * 10.0)
			
	var reload_pressed = Input.is_action_just_pressed("reload") if not is_bot else bot_wants_reload
	if reload_pressed and current_weapon and not is_reloading:
		_start_reload()

	var fire_pressed = Input.is_action_pressed("fire") if not is_bot else bot_wants_fire
	if fire_pressed and can_fire and not is_reloading and current_weapon:
		fire_weapon()
		
	if Input.is_action_just_pressed("switch_weapon_1") and primary_weapon:
		equip_weapon(primary_weapon)
	elif Input.is_action_just_pressed("switch_weapon_2") and secondary_weapon:
		equip_weapon(secondary_weapon)
	elif Input.is_action_just_pressed("switch_weapon_3") and melee_weapon:
		equip_weapon(melee_weapon)
		
	if Input.is_action_just_pressed("drop_weapon") and current_weapon and current_weapon != melee_weapon:
		rpc_id(1, "server_drop_weapon")
		
	if Input.is_action_just_pressed("throw_grenade") and grenades_count > 0:
		grenades_count -= 1
		var h = get_node_or_null("HUD")
		if h and h.has_method("update_ammo"): h.update_ammo(current_ammo, reserve_ammo) # Or a dedicated grenade counter
		rpc_id(1, "server_throw_grenade", camera.global_transform)

@rpc("any_peer", "call_local", "reliable")
func server_drop_weapon():
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	if current_weapon and current_weapon != melee_weapon:
		_spawn_weapon_drop(current_weapon, global_position + Vector3(0, 1.5, 0))
		rpc("client_dropped_weapon")

func _spawn_weapon_drop(wpn: WeaponData, pos: Vector3):
	var drop_scene = load("res://scenes/weapons/weapon_drop.tscn")
	if drop_scene:
		var d = drop_scene.instantiate()
		d.weapon_data = wpn
		d.position = pos
		get_node("/root/World").add_child(d)

@rpc("authority", "call_local", "reliable")
func client_dropped_weapon():
	if current_weapon == primary_weapon:
		primary_weapon = null
	elif current_weapon == secondary_weapon:
		secondary_weapon = null
		
	if secondary_weapon: equip_weapon(secondary_weapon)
	elif primary_weapon: equip_weapon(primary_weapon)
	elif melee_weapon: equip_weapon(melee_weapon)
	else:
		if current_viewmodel: current_viewmodel.queue_free()
		current_weapon = null

@rpc("authority", "call_local", "reliable")
func client_pickup_weapon(path: String):
	if not is_multiplayer_authority(): return
	var wpn = load(path)
	if wpn.weapon_name == "Pistol" or wpn.weapon_name == "Glock":
		secondary_weapon = wpn
	else:
		primary_weapon = wpn
	equip_weapon(wpn)

func _start_reload():
	if current_ammo == current_weapon.mag_size or reserve_ammo <= 0: return
	is_reloading = true
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_2d(am.reload_sound)
	
	if current_viewmodel:
		var t = create_tween()
		var down_pos = current_weapon.default_position + Vector3(0, -0.6, 0.2)
		t.tween_property(current_viewmodel, "position", down_pos, current_weapon.reload_time * 0.4).set_ease(Tween.EASE_IN)
		t.tween_property(current_viewmodel, "position", current_weapon.default_position, current_weapon.reload_time * 0.4).set_delay(current_weapon.reload_time * 0.2).set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(current_weapon.reload_time).timeout
	
	var needed = current_weapon.mag_size - current_ammo
	var reloaded = min(needed, reserve_ammo)
	current_ammo += reloaded
	reserve_ammo -= reloaded
	if get_node_or_null("HUD"): get_node("HUD").update_ammo(current_ammo, reserve_ammo)
	
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
		
	current_ammo = current_weapon.mag_size
	if get_node_or_null("HUD"): get_node("HUD").update_ammo(current_ammo, reserve_ammo)

func fire_weapon():
	if current_ammo <= 0:
		_start_reload()
		return
		
	current_ammo -= 1
	if get_node_or_null("HUD"): get_node("HUD").update_ammo(current_ammo, reserve_ammo)
	
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
		var light = current_viewmodel.get_node_or_null("MuzzleLight")
		if light and light is OmniLight3D:
			light.visible = true
			var t = create_tween()
			t.tween_property(light, "visible", false, 0.05).set_delay(0.05)
			
		var flash_scene = load("res://scenes/effects/muzzle_flash.tscn")
		if flash_scene:
			var f = flash_scene.instantiate()
			current_viewmodel.add_child(f)
			f.position = Vector3(0, 0, -1.0)
			f.emitting = true
			var smoke = f.get_node_or_null("Smoke")
			if smoke: smoke.emitting = true
			get_tree().create_timer(1.0).timeout.connect(f.queue_free)
			
		var shell_scene = load("res://scenes/effects/bullet_shell.tscn")
		if shell_scene:
			var shell = shell_scene.instantiate()
			var world = get_node_or_null("/root/World")
			if world:
				world.add_child(shell)
				shell.global_transform = current_viewmodel.global_transform
				shell.global_position += shell.global_transform.basis.x * 0.1 + shell.global_transform.basis.y * 0.1
			
	if gunshot_audio:
		var am = get_node_or_null("/root/AudioManager")
		if am: gunshot_audio.stream = am.gunshot_sound
		gunshot_audio.play()
	
	# Send request to server
	var base_dir = -camera.global_transform.basis.z
	var spread_factor = (hud_spread / 100.0) * 0.15 # Max spread amount
	var random_x = randf_range(-spread_factor, spread_factor)
	var random_y = randf_range(-spread_factor, spread_factor)
	var spread_dir = (base_dir + camera.global_transform.basis.x * random_x + camera.global_transform.basis.y * random_y).normalized()
	
	rpc_id(1, "request_fire", camera.global_transform.origin, spread_dir * current_weapon.range)

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
		var is_blood = false
		if target.has_method("take_damage"):
			is_blood = true
			target.take_damage(current_weapon.damage, team, get_multiplayer_authority(), current_weapon.weapon_name)
			rpc_id(multiplayer.get_remote_sender_id(), "client_hit_marker")
			
		rpc("client_spawn_impact", result.position, result.normal, is_blood)

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
func client_hit_marker():
	if get_node_or_null("HUD"): get_node("HUD").show_hit_marker()

@rpc("any_peer", "call_local", "reliable")
func server_throw_grenade(cam_transform: Transform3D):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	
	var g_scene = load("res://scenes/weapons/grenade.tscn")
	var g = g_scene.instantiate()
	get_node("/root/World").add_child(g)
	
	g.global_position = cam_transform.origin - cam_transform.basis.z * 1.0
	g.linear_velocity = -cam_transform.basis.z * 18.0 + Vector3(0, 4.0, 0)
	g.set_thrower_info(sender, team)

func _on_weapon_timer_timeout():
	can_fire = true

func take_damage(amount: int, attacker_team: Team.TeamId, attacker_id: int = 1, weapon_name: String = "Weapon"):
	if not multiplayer.is_server(): return
	if MatchManager.current_state != MatchManager.MatchState.LIVE: return
	if NetworkManager.is_team_mode and attacker_team == team: return
	
	var actual_damage = amount
	if armor > 0:
		actual_damage = amount / 2
		armor -= amount / 2
		if armor < 0: armor = 0
		
	health -= actual_damage
	rpc("sync_health", health, armor)
	
	if health <= 0:
		die(attacker_id, weapon_name)

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: int, new_armor: int = 0):
	health = new_health
	armor = new_armor
	if get_node_or_null("HUD"): get_node("HUD").update_health(health)
	if health <= 0 and not multiplayer.is_server():
		pass # Client side death effects

func die(attacker_id: int, weapon_name: String = "Weapon"):
	if not multiplayer.is_server(): return
	if get_node_or_null("Camera3D/SettingsMenu") and get_node("Camera3D/SettingsMenu").visible:
		get_node("Camera3D/SettingsMenu").close_menu()
	
	MatchManager.add_money(attacker_id, 300)
	PlayerStats.record_kill_event(attacker_id, name.to_int(), weapon_name)
	
	var attacker_name = "Player " + str(attacker_id)
	if PlayerStats.stats.has(attacker_id):
		attacker_name = PlayerStats.stats[attacker_id]["name"]
		
	var victim_name = "Player " + name
	if PlayerStats.stats.has(name.to_int()):
		victim_name = PlayerStats.stats[name.to_int()]["name"]
		
	var wpn_name = current_weapon.weapon_name if current_weapon else "Unknown"
	var kill_text = "%s eliminated %s [%s]" % [attacker_name, victim_name, wpn_name]
	
	if has_bomb:
		pass # drop bomb
		
	if primary_weapon:
		_spawn_weapon_drop(primary_weapon, global_position + Vector3(0, 1, 0))
	elif secondary_weapon:
		_spawn_weapon_drop(secondary_weapon, global_position + Vector3(0, 1, 0))
	
	rpc("sync_death", kill_text)
	queue_free()

@rpc("authority", "call_remote", "reliable")
func sync_death(kill_text: String = ""):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and kill_text != "":
		hud.add_kill_feed(kill_text)
	queue_free()
