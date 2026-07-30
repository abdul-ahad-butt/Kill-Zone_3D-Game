extends Node3D
class_name WeaponController

@export var character: BaseCharacter
@export var weapon_data: WeaponData

var current_ammo: int = 0
var current_reserve: int = 0
var is_reloading: bool = false
var last_fire_time: float = 0.0
var current_recoil_index: int = 0
var time_since_last_shot: float = 0.0
var sway_time: float = 0.0

signal recoil_applied(recoil_vector: Vector2)

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var muzzle_light: OmniLight3D

func _ready():
	if weapon_data:
		equip(weapon_data)
		
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.8, 0.3)
	muzzle_light.light_energy = 0.0
	muzzle_light.shadow_enabled = true
	add_child(muzzle_light)

func equip(new_weapon: WeaponData):
	weapon_data = new_weapon
	current_ammo = weapon_data.magazine_size
	current_reserve = weapon_data.reserve_ammo

func _process(delta):
	time_since_last_shot += delta
	if time_since_last_shot > 0.5:
		current_recoil_index = 0
		
	_apply_sway(delta)

func _apply_sway(delta):
	if not is_multiplayer_authority() or not character: return
	
	sway_time += delta
	var speed = character.velocity.length()
	var is_ads = false
	if character.has_method("is_ads"):
		is_ads = character.is_ads
	elif "is_ads" in character:
		is_ads = character.is_ads
		
	var sway_amount = 0.01 if is_ads else 0.05
	var bob_amount = 0.02 if is_ads else 0.1
	if speed > 0.1:
		# Moving bob
		var bob_x = sin(sway_time * 10.0) * bob_amount
		var bob_y = abs(cos(sway_time * 10.0)) * bob_amount
		position = position.lerp(Vector3(bob_x, bob_y, 0), delta * 5.0)
	else:
		# Idle sway
		var sway_x = sin(sway_time * 2.0) * sway_amount
		var sway_y = cos(sway_time * 3.0) * sway_amount * 0.5
		position = position.lerp(Vector3(sway_x, sway_y, 0), delta * 2.0)

func fire(is_ads: bool, is_moving: bool) -> bool:
	if is_reloading or current_ammo <= 0 or not weapon_data:
		return false
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_fire_time < 1.0 / weapon_data.fire_rate:
		return false
		
	last_fire_time = current_time
	time_since_last_shot = 0.0
	current_ammo -= 1
	
	_play_fire_effects()
	_apply_recoil_and_spread(is_ads, is_moving)
	_perform_hitscan()
	_emit_noise(30.0)
	
	_apply_procedural_kick()
	
	
	return true
	
func _emit_noise(radius: float):
	var all_ai = get_tree().get_nodes_in_group("ai")
	for ai in all_ai:
		if ai.global_position.distance_to(global_position) <= radius:
			if ai.has_method("hear_noise"):
				ai.hear_noise(global_position)

func _play_fire_effects():
	if weapon_data.fire_sound:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_3d(weapon_data.fire_sound, global_position)
		
	if muzzle_light:
		muzzle_light.light_energy = 5.0
		var tween = create_tween()
		tween.tween_property(muzzle_light, "light_energy", 0.0, 0.05)
		
	var builtin_flash = get_node_or_null("../PistolViewmodel/MuzzleFlash")
	if builtin_flash and builtin_flash is CPUParticles3D:
		builtin_flash.restart()
		builtin_flash.emitting = true
		
	if weapon_data.muzzle_flash_scene:
		var flash = weapon_data.muzzle_flash_scene.instantiate()
		add_child(flash)
		
	# Eject shell
	_spawn_shell()

func _spawn_shell():
	# Procedural simple shell eject
	var shell = RigidBody3D.new()
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.05
	mesh.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3
	mesh.material_override = mat
	shell.add_child(mesh)
	
	var col = CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 0.02
	col.shape.height = 0.05
	shell.add_child(col)
	
	shell.collision_layer = 0
	shell.collision_mask = 1 # Collide with world
	
	get_tree().current_scene.add_child(shell)
	shell.global_position = global_position + global_transform.basis.x * 0.1 + global_transform.basis.y * 0.1
	var eject_dir = (global_transform.basis.x + global_transform.basis.y + Vector3(randf_range(-0.2,0.2), randf_range(-0.2,0.2), randf_range(-0.2,0.2))).normalized()
	shell.apply_impulse(eject_dir * randf_range(2.0, 3.0))
	
	# Auto destroy
	get_tree().create_timer(3.0).timeout.connect(shell.queue_free)

func _apply_recoil_and_spread(is_ads: bool, is_moving: bool):
	var spread = weapon_data.spread_base
	if is_moving: spread += weapon_data.spread_moving
	if is_ads: spread *= weapon_data.spread_ads
	
	if weapon_data.recoil_pattern.size() > 0:
		var recoil_vec = weapon_data.recoil_pattern[current_recoil_index % weapon_data.recoil_pattern.size()]
		current_recoil_index += 1
		recoil_applied.emit(recoil_vec)

func _perform_hitscan():
	if not multiplayer.is_server(): return
	
	var space_state = get_world_3d().direct_space_state
	var end_point = global_position - global_transform.basis.z * weapon_data.range
	var query = PhysicsRayQueryParameters3D.create(global_position, end_point)
	
	var result = space_state.intersect_ray(query)
	var hit_pos = end_point
	
	if result:
		hit_pos = result.position
		var collider = result.collider
		
		var character_node = collider
		while character_node and not character_node is BaseCharacter:
			character_node = character_node.get_parent()
			
		if character_node is BaseCharacter:
			var damage = weapon_data.damage
			var is_hs = false
			if collider is Area3D:
				if "head" in collider.name.to_lower():
					damage *= 2.5
					is_hs = true
				elif "limb" in collider.name.to_lower() or "leg" in collider.name.to_lower() or "arm" in collider.name.to_lower():
					damage *= 0.75
			
			var distance = global_position.distance_to(result.position)
			if weapon_data.range_falloff_curve:
				damage *= weapon_data.range_falloff_curve.sample(distance / weapon_data.range)
				
			var attacker_faction = character.faction if character else BaseCharacter.Faction.NONE
			var attacker_id = character.name.to_int() if character else 1
			character_node.take_damage(int(damage), attacker_faction, attacker_id, weapon_data.weapon_name)
			
			var sender = multiplayer.get_remote_sender_id()
			if sender == 0: sender = 1 # Local server player
			rpc_id(sender, "client_hit_marker", is_hs)
			
			rpc("spawn_impact", hit_pos, result.normal, 1)
		else:
			# Hit environment
			rpc("spawn_impact", hit_pos, result.normal, 0)
			
	# Spawn tracer for everyone
	rpc("spawn_tracer", global_position, hit_pos)

@rpc("authority", "call_local", "unreliable")
func spawn_tracer(start: Vector3, end: Vector3):
	# Only do every few shots or randomly to avoid clutter
	if randf() > 0.5: return
	
	var mesh = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	
	get_tree().current_scene.add_child(mi)
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(mi.queue_free)

@rpc("authority", "call_local", "unreliable")
func spawn_impact(pos: Vector3, normal: Vector3, type: int = 0):
	var impact_scene
	if type == 0:
		impact_scene = load("res://scenes/effects/bullet_impact.tscn")
	else:
		impact_scene = load("res://scenes/effects/blood_impact.tscn")
		
	if impact_scene:
		var impact = impact_scene.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.global_position = pos
		if normal != Vector3.UP and normal != Vector3.DOWN and normal.length_squared() > 0:
			impact.look_at(pos + normal, Vector3.UP)
		elif normal == Vector3.UP:
			impact.rotation_degrees.x = 90
		elif normal == Vector3.DOWN:
			impact.rotation_degrees.x = -90

@rpc("authority", "call_local", "unreliable")
func client_hit_marker(is_hs: bool):
	get_tree().call_group("hud", "show_hit_marker")
	var am = get_node_or_null("/root/AudioManager")
	if am and am.button_sound: # Use a sound, higher pitch for headshot
		var player = AudioStreamPlayer.new()
		player.stream = am.button_sound
		player.pitch_scale = 1.5 if is_hs else 1.0
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

func reload():
	if is_reloading or current_ammo == weapon_data.magazine_size or current_reserve <= 0:
		return
		
	is_reloading = true
	if weapon_data.reload_sound:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_3d(weapon_data.reload_sound, global_position)
		
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:x", -45.0, 0.3)
	tween.tween_property(self, "rotation_degrees:z", 30.0, 0.3)
	tween.tween_interval(max(0.1, weapon_data.reload_time - 0.9))
	tween.tween_property(self, "rotation_degrees:z", 0.0, 0.3)
	tween.tween_property(self, "rotation_degrees:x", 0.0, 0.3)
		
	await get_tree().create_timer(weapon_data.reload_time).timeout
	
	var needed = weapon_data.magazine_size - current_ammo
	var amount_to_reload = min(needed, current_reserve)
	current_ammo += amount_to_reload
	current_reserve -= amount_to_reload
	
	is_reloading = false

func _apply_procedural_kick():
	var tween = create_tween()
	var original_pos = Vector3.ZERO
	var kick_z = randf_range(0.05, 0.1)
	var kick_up = randf_range(2.0, 5.0)
	tween.tween_property(self, "position:z", original_pos.z + kick_z, 0.05)
	tween.parallel().tween_property(self, "rotation_degrees:x", kick_up, 0.05)
	tween.tween_property(self, "position:z", original_pos.z, 0.15)
	tween.parallel().tween_property(self, "rotation_degrees:x", 0.0, 0.15)
