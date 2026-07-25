extends Node3D

@export var grass_count: int = 15000
@export var map_radius: float = 90.0

func _ready():
	_generate_grass()
	_spawn_tactical_cover()

func is_inside_building(x: float, z: float) -> bool:
	if abs(x) < 6 and abs(z) < 6: return true
	if abs(x - (-40)) < 9 and abs(z) < 9: return true
	if abs(x - 40) < 9 and abs(z) < 9: return true
	return false

func _generate_grass():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = grass_count
	
	# Generate procedural grass blade texture
	var img = Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(16):
			var width_at_y = lerp(8.0, 0.0, float(y) / 64.0)
			var center_dist = abs(x - 8)
			if center_dist <= width_at_y:
				# Add some color variation from base to tip
				var c = lerp(Color(0.15, 0.35, 0.1), Color(0.3, 0.6, 0.15), float(y) / 64.0)
				img.set_pixel(x, 63 - y, c)
			else:
				img.set_pixel(x, 63 - y, Color(0, 0, 0, 0))
	var tex = ImageTexture.create_from_image(img)
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.3, 0.8)
	mesh.center_offset = Vector3(0, 0.4, 0)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	mesh.material = mat
	multimesh.mesh = mesh
	
	for i in range(grass_count):
		var x = randf_range(-map_radius, map_radius)
		var z = randf_range(-map_radius, map_radius)
		
		if not is_inside_building(x, z):
			var pos = Vector3(x, 0, z)
			var t = Transform3D().translated(pos)
			t = t.rotated(Vector3.UP, randf() * TAU)
			t = t.scaled(Vector3.ONE * randf_range(0.7, 1.3))
			multimesh.set_instance_transform(i, t)
		else:
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
