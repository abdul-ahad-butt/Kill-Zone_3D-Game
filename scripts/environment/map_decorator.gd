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
	
	var vertices = PackedVector3Array()
	# Triangle 1 (X-axis) - much smaller blades
	vertices.push_back(Vector3(-0.05, 0, 0))
	vertices.push_back(Vector3(0.05, 0, 0))
	vertices.push_back(Vector3(0, 0.25, 0))
	
	# Triangle 2 (Z-axis)
	vertices.push_back(Vector3(0, 0, -0.05))
	vertices.push_back(Vector3(0, 0, 0.05))
	vertices.push_back(Vector3(0, 0.25, 0))
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var shader_code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(0.25, 0.45, 0.15, 1.0);
uniform float sway_speed = 2.0;
uniform float sway_strength = 0.05;

void vertex() {
	if (VERTEX.y > 0.0) {
		float time = TIME * sway_speed;
		VERTEX.x += sin(time + NODE_POSITION_WORLD.x) * sway_strength;
		VERTEX.z += cos(time + NODE_POSITION_WORLD.z) * sway_strength;
	}
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.9;
}
"""
	var shader = Shader.new()
	shader.code = shader_code
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mesh.surface_set_material(0, mat)
	multimesh.mesh = mesh
	
	var valid_instances = 0
	for i in range(grass_count):
		var x = randf_range(-map_radius, map_radius)
		var z = randf_range(-map_radius, map_radius)
		
		# Improved masking
		if not is_inside_building(x, z):
			# Also avoid road/paths roughly (x around 0)
			if abs(x) < 4.0:
				continue
				
			var pos = Vector3(x, 0, z)
			var t = Transform3D().translated(pos)
			t = t.rotated(Vector3.UP, randf() * TAU)
			t = t.scaled(Vector3.ONE * randf_range(0.6, 1.2))
			multimesh.set_instance_transform(valid_instances, t)
			valid_instances += 1
			
	multimesh.visible_instance_count = valid_instances
	
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
		
	_create_furniture(Vector3(-40, 0.5, 2), crate_mat)
	_create_furniture(Vector3(-40, 0.5, -2), crate_mat)
	_create_furniture(Vector3(40, 0.5, 2), crate_mat)
	_create_furniture(Vector3(40, 0.5, -2), crate_mat)
	
	var lightA = OmniLight3D.new()
	lightA.position = Vector3(-40, 5, 0)
	lightA.omni_range = 15.0
	lightA.light_energy = 2.0
	lightA.light_color = Color(1.0, 0.9, 0.7)
	add_child(lightA)
	
	var lightB = OmniLight3D.new()
	lightB.position = Vector3(40, 5, 0)
	lightB.omni_range = 15.0
	lightB.light_energy = 2.0
	lightB.light_color = Color(1.0, 0.9, 0.7)
	add_child(lightB)
	
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
	
	var rigid = RigidBody3D.new()
	rigid.mass = 10.0
	rigid.position = pos
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	rigid.add_child(col)
	rigid.add_child(mesh)
	
	add_child(rigid)

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

func _create_furniture(pos: Vector3, mat: Material):
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(3, 0.2, 1.5)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos + Vector3(0, 1.0, 0)
	
	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	sb.add_child(col)
	mesh.add_child(sb)
	
	for x in [-1.4, 1.4]:
		for z in [-0.6, 0.6]:
			var leg = MeshInstance3D.new()
			var lbox = BoxMesh.new()
			lbox.size = Vector3(0.2, 1.0, 0.2)
			leg.mesh = lbox
			leg.material_override = mat
			leg.position = Vector3(x, -0.5, z)
			mesh.add_child(leg)
	
	add_child(mesh)
