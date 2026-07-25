extends RigidBody3D

@export var fuse_time: float = 3.0
@export var blast_radius: float = 12.0
@export var max_damage: float = 100.0

@onready var mesh = $MeshInstance3D
@onready var particles = $ExplosionParticles
@onready var light = $ExplosionLight
@onready var fuse_timer = $FuseTimer

var thrower_id: int = 1
var thrower_team: int = 0

func _ready():
	if multiplayer.is_server():
		fuse_timer.wait_time = fuse_time
		fuse_timer.start()
		fuse_timer.timeout.connect(_on_explode)

func set_thrower_info(id: int, team: int):
	thrower_id = id
	thrower_team = team

func _on_explode():
	rpc("client_explode")
	_apply_damage()
	
	# Delay freeing the server object slightly to let clients process particles
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _apply_damage():
	if not multiplayer.is_server(): return
	var space = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = blast_radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 2 # Players & Bots
	
	var results = space.intersect_shape(query)
	for result in results:
		var col = result.collider
		if col and col.has_method("take_damage"):
			var dist = global_position.distance_to(col.global_position)
			var damage_factor = 1.0 - (dist / blast_radius)
			if damage_factor < 0: damage_factor = 0
			var dmg = int(max_damage * damage_factor)
			if dmg > 0:
				col.take_damage(dmg, thrower_team, thrower_id)

@rpc("call_local", "reliable")
func client_explode():
	if mesh: mesh.visible = false
	sleeping = true
	freeze = true
	
	if particles: particles.emitting = true
	if light:
		light.visible = true
		var tw = create_tween()
		tw.tween_property(light, "light_energy", 0.0, 0.5)
	
	# Explode sound
	var audio = AudioStreamPlayer3D.new()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("get_node"):
		# Using the bomb explosion sound for grenades
		var bs = am.get_node_or_null("BombExplodeSound")
		if bs:
			audio.stream = bs.stream
	audio.position = global_position
	audio.unit_size = 15.0
	get_tree().current_scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
