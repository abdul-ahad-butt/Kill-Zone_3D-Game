extends SceneTree

func _init():
	var scene = load("res://scenes/world.tscn")
	if not scene:
		print("Failed to load world.tscn")
		quit()
		return
	
	var root = scene.instantiate()
	
	# Materials
	var mat_concrete = load("res://resources/materials/concrete.tres")
	var mat_brick = load("res://resources/materials/brick.tres")
	var mat_dirt = load("res://resources/materials/dirt.tres")
	var mat_metal = load("res://resources/materials/metal.tres")
	
	# Apply to Ground
	var nav = root.get_node_or_null("NavigationRegion3D")
	if nav:
		var geom = nav.get_node_or_null("MapGeometry")
		if geom:
			geom.material_override = mat_concrete
			var ground = geom.get_node_or_null("Ground")
			if ground:
				ground.material = mat_dirt
			var bA = geom.get_node_or_null("BuildingA")
			if bA: bA.material = mat_brick
			var bB = geom.get_node_or_null("BuildingB")
			if bB: bB.material = mat_brick
			var center = geom.get_node_or_null("CenterStructure")
			if center: center.material = mat_metal
			var cw1 = geom.get_node_or_null("CoverWall1")
			if cw1: cw1.material = mat_concrete
			var cw2 = geom.get_node_or_null("CoverWall2")
			if cw2: cw2.material = mat_concrete
	
	# Environment
	if not root.has_node("WorldEnvironment"):
		var env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		var env = Environment.new()
		var sky = Sky.new()
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.3, 0.45, 0.6)
		sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.8)
		sky_mat.ground_bottom_color = Color(0.15, 0.15, 0.15)
		sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.8)
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.ssr_enabled = true
		env.ssao_enabled = true
		env_node.environment = env
		root.add_child(env_node)
		env_node.owner = root
	
	var light = root.get_node_or_null("DirectionalLight3D")
	if light:
		light.shadow_enabled = true
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_fade_start = 1.0
		light.directional_shadow_max_distance = 200.0
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/world.tscn")
	print("Successfully updated world.tscn")
	quit()
