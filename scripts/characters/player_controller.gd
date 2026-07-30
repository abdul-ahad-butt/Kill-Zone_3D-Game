extends BaseCharacter
class_name PlayerController

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_crouching: bool = false
var is_sprinting: bool = false
var is_ads: bool = false

var default_fov: float = 75.0
var ads_fov: float = 50.0
var ads_speed_multiplier: float = 0.6

@onready var camera = $Camera3D
@onready var weapon_controller = $Camera3D/WeaponController

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	super._ready()
	add_to_group("players")
	if not is_multiplayer_authority():
		if camera: camera.current = false
		return
		
	if weapon_controller:
		weapon_controller.recoil_applied.connect(_on_recoil_applied)
		
	if camera: 
		camera.current = true
		default_fov = camera.fov
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag:
		if event.position.x > get_viewport().size.x / 2.0:
			_rotate_camera(event.relative)

func _rotate_camera(relative: Vector2):
	rotate_y(-relative.x * 0.005)
	if camera:
		camera.rotate_x(-relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _on_recoil_applied(recoil_vector: Vector2):
	if camera:
		camera.rotate_x(deg_to_rad(recoil_vector.y))
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	rotate_y(deg_to_rad(recoil_vector.x))

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
		
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and not is_crouching
	
	var current_speed = SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif is_sprinting and not is_ads:
		current_speed = SPRINT_SPEED
		
	if is_ads:
		current_speed *= ads_speed_multiplier
		
	if camera:
		camera.position.y = lerp(camera.position.y, 1.0 if is_crouching else 1.6, delta * 10.0)
		
		# Handle ADS FOV
		var target_fov = ads_fov if is_ads else default_fov
		camera.fov = lerp(camera.fov, target_fov, delta * 15.0)

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	is_ads = Input.is_action_pressed("ads")

	if Input.is_action_pressed("fire"):
		if weapon_controller:
			var is_moving = velocity.length_squared() > 0.1
			weapon_controller.fire(is_ads, is_moving)
			
	if Input.is_action_just_pressed("reload"):
		if weapon_controller:
			weapon_controller.reload()

	move_and_slide()
	_check_rain()

var _was_under_roof: bool = false
var _rain_particles = null

func _check_rain():
	if Engine.get_frames_drawn() % 10 != 0: return
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.UP * 20.0)
	var result = space_state.intersect_ray(query)
	var is_under_roof = result.size() > 0
	
	if is_under_roof != _was_under_roof:
		_was_under_roof = is_under_roof
		_fade_rain(not is_under_roof)

func _fade_rain(show: bool):
	if not is_instance_valid(_rain_particles):
		var world = get_tree().current_scene
		if world:
			for c in world.get_children():
				if c is GPUParticles3D or c is CPUParticles3D:
					if "amount" in c and c.amount > 1000:
						_rain_particles = c
						break
	
	if _rain_particles:
		var target_alpha = 0.3 if show else 0.0
		var pass_mat = null
		if _rain_particles is GPUParticles3D:
			pass_mat = _rain_particles.draw_pass_1.material
		elif _rain_particles is CPUParticles3D:
			pass_mat = _rain_particles.mesh.material
			
		if pass_mat and pass_mat is StandardMaterial3D:
			var tween = create_tween()
			tween.tween_property(pass_mat, "albedo_color:a", target_alpha, 0.5)

