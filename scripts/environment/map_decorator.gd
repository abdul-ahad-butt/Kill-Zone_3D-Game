extends Node3D

@export var grass_count: int = 15000
@export var map_radius: float = 90.0

func _ready():
	_generate_grass()
	_spawn_tactical_cover()

func _generate_grass():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = grass_count
	
	# Create a simple grass blade mesh
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.5, 0.8)
	mesh.center_offset = Vector3(0, 0.4, 0)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.45, 0.15, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	mesh.material = mat
	multimesh.mesh = mesh
	
	for i in range(grass_count):
		var x = randf_range(-map_radius, map_radius)
		var z = randf_range(-map_radius, map_radius)
		
		# Keep grass outside buildings
		if abs(x) > 12 or abs(z) > 12:
			var pos = Vector3(x, 0, z)
			var t = Transform3D().translated(pos)
			t = t.rotated(Vector3.UP, randf() * TAU)
			# Random scale
			t = t.scaled(Vector3.ONE * randf_range(0.8, 1.2))
			multimesh.set_instance_transform(i, t)
		else:
			# Hide unused instances by placing them underground
			multimesh.set_instance_transform(i, Transform3D().translated(Vector3(0, -10, 0)))
			
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _spawn_tactical_cover():
	# Define a crate
	var crate_mat = load("res://Assets/textures/mat_wood.tres")
	if not crate_mat:
		crate_mat = StandardMaterial3D.new()
		crate_mat.albedo_color = Color(0.4, 0.25, 0.15)
		
	# Define sandbags
	var sandbag_mat = load("res://Assets/textures/mat_sandbag.tres")
	if not sandbag_mat:
		sandbag_mat = StandardMaterial3D.new()
		sandbag_mat.albedo_color = Color(0.6, 0.55, 0.4)
		
	_create_crate(Vector3(-12, 1, 10), crate_mat)
	_create_crate(Vector3(-12, 1, 12), crate_mat)
	_create_crate(Vector3(-12, 3, 11), crate_mat)
	
	_create_crate(Vector3(12, 1, -10), crate_mat)
	_create_crate(Vector3(12, 1, -12), crate_mat)
	
	_create_crate(Vector3(30, 1, 30), crate_mat)
	_create_crate(Vector3(32, 1, 30), crate_mat)
	_create_crate(Vector3(-30, 1, -30), crate_mat)
	_create_crate(Vector3(-28, 1, -30), crate_mat)
	
	_create_sandbag(Vector3(-5, 0.5, -20), sandbag_mat)
	_create_sandbag(Vector3(5, 0.5, 20), sandbag_mat)
	_create_sandbag(Vector3(-20, 0.5, 20), sandbag_mat)
	_create_sandbag(Vector3(20, 0.5, -20), sandbag_mat)

func _create_crate(pos: Vector3, mat: Material):
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	static_body.add_child(col)
	mesh.add_child(static_body)
	
	add_child(mesh)

func _create_sandbag(pos: Vector3, mat: Material):
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4, 1.5, 1)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	static_body.add_child(col)
	mesh.add_child(static_body)
	
	add_child(mesh)
