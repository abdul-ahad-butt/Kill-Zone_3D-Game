extends SceneTree

func _init():
	var viewmodels = [
		"res://Assets/models/weapons/rifle_viewmodel.tscn",
		"res://Assets/models/weapons/pistol_viewmodel.tscn",
		"res://Assets/models/weapons/smg_viewmodel.tscn"
	]
	
	for path in viewmodels:
		var scene = load(path)
		if not scene: continue
		var root = scene.instantiate()
		
		# Better Mesh Layout
		var mesh = root.get_node_or_null("MeshInstance3D")
		if mesh:
			# Just making sure they look a bit more complex (adding a magazine or scope if none exist)
			if not root.has_node("Magazine"):
				var mag = MeshInstance3D.new()
				mag.name = "Magazine"
				var box = BoxMesh.new()
				box.size = Vector3(0.05, 0.15, 0.08)
				
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.1, 0.1, 0.1)
				box.material = mat
				
				mag.mesh = box
				# Relative to mesh
				mag.position = Vector3(0.3, -0.4, -0.4)
				root.add_child(mag)
				mag.owner = root
				
		var flash = root.get_node_or_null("MuzzleFlash")
		if flash:
			if not root.has_node("MuzzleLight"):
				var light = OmniLight3D.new()
				light.name = "MuzzleLight"
				light.position = flash.position
				light.light_color = Color(1.0, 0.8, 0.2)
				light.light_energy = 5.0
				light.omni_range = 10.0
				light.shadow_enabled = true
				light.visible = false
				root.add_child(light)
				light.owner = root
		
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, path)
		
	print("Successfully updated weapons")
	quit()
