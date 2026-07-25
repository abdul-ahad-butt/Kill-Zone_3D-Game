extends Node3D

@export var team: int = 0 # 0=None, 1=Police, 2=Terrorist

var anim_player: AnimationPlayer
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var time: float = 0.0
var current_anim: String = "idle"

func _ready():
	_build_rig()
	_apply_materials()

func _build_rig():
	# Torso
	torso = _create_box(Vector3(0.5, 0.7, 0.3), Vector3(0, 0.35, 0))
	add_child(torso)
	
	# Head
	head = _create_box(Vector3(0.3, 0.3, 0.3), Vector3(0, 0.9, 0))
	add_child(head)
	
	# Helmet / Mask
	var accessory = MeshInstance3D.new()
	if team == 1:
		# Police Helmet
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.16
		cyl.height = 0.15
		accessory.mesh = cyl
		accessory.position = Vector3(0, 0.16, 0)
	else:
		# Terrorist Mask (Bandana/Visor)
		var box = BoxMesh.new()
		box.size = Vector3(0.31, 0.1, 0.31)
		accessory.mesh = box
		accessory.position = Vector3(0, -0.05, 0)
	head.add_child(accessory)
	
	# Arms (Parents for rotation)
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.35, 0.6, 0)
	add_child(arm_l)
	var arm_l_mesh = _create_box(Vector3(0.15, 0.6, 0.15), Vector3(0, -0.25, 0))
	arm_l.add_child(arm_l_mesh)
	
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.35, 0.6, 0)
	add_child(arm_r)
	var arm_r_mesh = _create_box(Vector3(0.15, 0.6, 0.15), Vector3(0, -0.25, 0))
	arm_r.add_child(arm_r_mesh)
	
	# Legs
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.15, 0, 0)
	add_child(leg_l)
	var leg_l_mesh = _create_box(Vector3(0.2, 0.7, 0.2), Vector3(0, -0.35, 0))
	leg_l.add_child(leg_l_mesh)
	
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.15, 0, 0)
	add_child(leg_r)
	var leg_r_mesh = _create_box(Vector3(0.2, 0.7, 0.2), Vector3(0, -0.35, 0))
	leg_r.add_child(leg_r_mesh)

func _create_box(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	return mi

func _apply_materials():
	var primary = Color(0.1, 0.2, 0.4) if team == 1 else Color(0.5, 0.4, 0.2)
	var secondary = Color(0.1, 0.1, 0.1) if team == 1 else Color(0.3, 0.3, 0.2)
	var skin = Color(0.9, 0.7, 0.6)
	
	var mat_primary = StandardMaterial3D.new()
	mat_primary.albedo_color = primary
	var mat_secondary = StandardMaterial3D.new()
	mat_secondary.albedo_color = secondary
	var mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = skin
	
	torso.set_surface_override_material(0, mat_primary)
	head.set_surface_override_material(0, mat_skin)
	arm_l.get_child(0).set_surface_override_material(0, mat_secondary)
	arm_r.get_child(0).set_surface_override_material(0, mat_secondary)
	leg_l.get_child(0).set_surface_override_material(0, mat_secondary)
	leg_r.get_child(0).set_surface_override_material(0, mat_secondary)
	
	if head.get_child_count() > 0:
		var acc = head.get_child(0)
		var mat_acc = StandardMaterial3D.new()
		mat_acc.albedo_color = Color(0.1, 0.1, 0.1) if team == 1 else Color(0.8, 0.2, 0.2)
		acc.set_surface_override_material(0, mat_acc)

func play_anim(anim: String):
	current_anim = anim

func _process(delta):
	time += delta
	if current_anim == "run" or current_anim == "walk":
		var speed = 10.0 if current_anim == "run" else 5.0
		var stride = 0.5 if current_anim == "run" else 0.3
		leg_l.rotation.x = sin(time * speed) * stride
		leg_r.rotation.x = -sin(time * speed) * stride
		arm_l.rotation.x = -sin(time * speed) * stride
		arm_r.rotation.x = sin(time * speed) * stride
	elif current_anim == "idle":
		leg_l.rotation.x = move_toward(leg_l.rotation.x, 0, delta * 2)
		leg_r.rotation.x = move_toward(leg_r.rotation.x, 0, delta * 2)
		arm_l.rotation.x = move_toward(arm_l.rotation.x, 0, delta * 2)
		arm_r.rotation.x = move_toward(arm_r.rotation.x, 0, delta * 2)
	
	# Procedural breathing
	torso.scale.y = 1.0 + sin(time * 2.0) * 0.02
	head.position.y = 0.9 + sin(time * 2.0) * 0.015
