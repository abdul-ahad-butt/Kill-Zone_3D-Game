extends RigidBody3D
class_name Grenade

var thrower_id: int
var thrower_team: int
var damage: int = 150
var explosion_radius: float = 8.0
var is_smoke: bool = false

func _ready():
	# Create visuals
	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.2) if not is_smoke else Color(0.8, 0.8, 0.8)
	mesh.surface_set_material(0, mat)
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	
	# Create collision
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.15
	collision.shape = shape
	add_child(collision)
	
	# Physics properties
	mass = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 0.5
	
	# Start fuse (smoke deploys faster)
	var fuse_time = 1.5 if is_smoke else 2.0
	await get_tree().create_timer(fuse_time).timeout
	explode()

func explode():
	if is_smoke:
		_deploy_smoke()
		return
		
	if not multiplayer.is_server() and not MatchManager.is_offline_solo:
		# Clients just show effect, server does damage
		show_explosion_effect()
		return
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	
	var results = space_state.intersect_shape(query)
	for res in results:
		var target = res.collider
		if target.has_method("take_damage"):
			var dist = global_position.distance_to(target.global_position)
			var dmg_falloff = 1.0 - (dist / explosion_radius)
			if dmg_falloff > 0:
				var final_damage = int(damage * dmg_falloff)
				target.take_damage(final_damage, thrower_team, thrower_id)
				
	if not MatchManager.is_offline_solo:
		rpc("show_explosion_effect")
	else:
		show_explosion_effect()

func _deploy_smoke():
	if not MatchManager.is_offline_solo:
		rpc("show_smoke_effect")
	else:
		show_smoke_effect()

@rpc("call_local", "reliable")
func show_smoke_effect():
	var smoke_mesh_inst = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	smoke_mesh_inst.mesh = mesh
	smoke_mesh_inst.global_position = global_position
	get_tree().root.add_child(smoke_mesh_inst)
	
	var t = create_tween()
	t.tween_property(smoke_mesh_inst, "scale", Vector3(6.0, 4.0, 6.0), 1.2).set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(8.0)
	t.tween_property(smoke_mesh_inst, "modulate:a", 0.0, 2.0)
	t.tween_callback(smoke_mesh_inst.queue_free)
	
	queue_free()

@rpc("call_local", "reliable")
func show_explosion_effect():
	# Simple explosion visual
	var explosion_mesh = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = explosion_radius
	mesh.height = explosion_radius * 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	explosion_mesh.mesh = mesh
	explosion_mesh.global_position = global_position
	get_tree().root.add_child(explosion_mesh)
	
	var t = create_tween()
	t.tween_property(explosion_mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
	t.tween_property(explosion_mesh, "modulate:a", 0.0, 0.4)
	t.tween_callback(explosion_mesh.queue_free)
	
	queue_free()
