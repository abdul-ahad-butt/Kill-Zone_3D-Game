extends Node3D

@export var grass_count: int = 5000
@export var map_radius: float = 40.0

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
	mat.transmission_enabled = true
	mat.transmission = Color(0.1, 0.3, 0.1)
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
	
	_create_sandbag(Vector3(-5, 0.5, -20), sandbag_mat)
	_create_sandbag(Vector3(5, 0.5, 20), sandbag_mat)

func _create_crate(pos: Vector3, mat: Material):
	var box = CSGBox3D.new()
	box.size = Vector3(2, 2, 2)
	box.position = pos
	box.material_override = mat
	box.use_collision = true
	add_child(box)

func _create_sandbag(pos: Vector3, mat: Material):
	var sb = CSGBox3D.new()
	sb.size = Vector3(4, 1.5, 1)
	sb.position = pos
	sb.material_override = mat
	sb.use_collision = true
	add_child(sb)
