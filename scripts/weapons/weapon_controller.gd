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

@onready var raycast: RayCast3D = $RayCast3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready():
	if weapon_data:
		equip(weapon_data)

func equip(new_weapon: WeaponData):
	weapon_data = new_weapon
	current_ammo = weapon_data.magazine_size
	current_reserve = weapon_data.reserve_ammo
	if raycast:
		raycast.target_position = Vector3(0, 0, -weapon_data.range)

func _process(delta):
	time_since_last_shot += delta
	if time_since_last_shot > 0.5: # Recoil reset threshold
		current_recoil_index = 0

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
	
	return true

func _play_fire_effects():
	if weapon_data.fire_sound:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_3d(weapon_data.fire_sound, global_position)
		
	if weapon_data.muzzle_flash_scene:
		var flash = weapon_data.muzzle_flash_scene.instantiate()
		add_child(flash)
		# Should self-destroy or emit once

func _apply_recoil_and_spread(is_ads: bool, is_moving: bool):
	var spread = weapon_data.spread_base
	if is_moving: spread += weapon_data.spread_moving
	if is_ads: spread *= weapon_data.spread_ads
	
	# Implement recoil logic by returning the kick vector to the camera/player
	if weapon_data.recoil_pattern.size() > 0:
		var recoil_vec = weapon_data.recoil_pattern[current_recoil_index % weapon_data.recoil_pattern.size()]
		current_recoil_index += 1
		# In a real game, signal or apply this to the camera rotation

func _perform_hitscan():
	if not multiplayer.is_server(): return # Only server registers hits
	
	if not raycast: return
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is BaseCharacter:
			# Get damage multiplier based on hit shape (Head/Body/Limbs) if available
			var damage = weapon_data.damage
			# Falloff logic
			var distance = global_position.distance_to(raycast.get_collision_point())
			if weapon_data.range_falloff_curve:
				damage *= weapon_data.range_falloff_curve.sample(distance / weapon_data.range)
				
			var attacker_faction = character.faction if character else BaseCharacter.Faction.NONE
			var attacker_id = character.name.to_int() if character else 1
			collider.take_damage(int(damage), attacker_faction, attacker_id, weapon_data.weapon_name)
			
			# Notify client for hit marker
			# rpc_id(multiplayer.get_remote_sender_id(), "client_hit_marker")

func reload():
	if is_reloading or current_ammo == weapon_data.magazine_size or current_reserve <= 0:
		return
		
	is_reloading = true
	if weapon_data.reload_sound:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_3d(weapon_data.reload_sound, global_position)
		
	await get_tree().create_timer(weapon_data.reload_time).timeout
	
	var needed = weapon_data.magazine_size - current_ammo
	var amount_to_reload = min(needed, current_reserve)
	current_ammo += amount_to_reload
	current_reserve -= amount_to_reload
	
	is_reloading = false
