@tool
extends SceneTree

func _init():
	var packed_scene = load("res://node_3d.tscn")
	if not packed_scene:
		print("Failed to load node_3d.tscn")
		quit()
		return
		
	var scene_root = packed_scene.instantiate()
	
	var bomb_a = scene_root.get_node_or_null("BombSiteA")
	var bomb_b = scene_root.get_node_or_null("BombSiteB")
	
	if bomb_a:
		var crate1 = CSGBox3D.new()
		crate1.name = "CoverA1"
		crate1.size = Vector3(2.0, 1.2, 1.0)
		crate1.use_collision = true
		crate1.position = bomb_a.position + Vector3(4.0, 0.6, 2.0)
		scene_root.add_child(crate1)
		crate1.owner = scene_root
		
		var crate2 = CSGBox3D.new()
		crate2.name = "CoverA2"
		crate2.size = Vector3(2.0, 1.2, 1.0)
		crate2.use_collision = true
		crate2.position = bomb_a.position + Vector3(-2.0, 0.6, -4.0)
		scene_root.add_child(crate2)
		crate2.owner = scene_root
		
	if bomb_b:
		var crate3 = CSGBox3D.new()
		crate3.name = "CoverB1"
		crate3.size = Vector3(4.0, 1.2, 1.0)
		crate3.use_collision = true
		crate3.position = bomb_b.position + Vector3(0.0, 0.6, 5.0)
		scene_root.add_child(crate3)
		crate3.owner = scene_root
		
		var crate4 = CSGBox3D.new()
		crate4.name = "CoverB2"
		crate4.size = Vector3(1.0, 1.2, 4.0)
		crate4.use_collision = true
		crate4.position = bomb_b.position + Vector3(-5.0, 0.6, 0.0)
		scene_root.add_child(crate4)
		crate4.owner = scene_root

	var new_packed = PackedScene.new()
	new_packed.pack(scene_root)
	ResourceSaver.save(new_packed, "res://node_3d.tscn")
	print("Map cover added successfully.")
	quit()
