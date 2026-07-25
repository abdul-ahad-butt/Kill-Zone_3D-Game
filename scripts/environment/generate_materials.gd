extends SceneTree

func _init():
	print("Starting material generation...")
	var dir = DirAccess.open("res://Assets")
	if not dir.dir_exists("textures"):
		dir.make_dir("textures")
		
	_generate_material("concrete", 0.5, 0.4, 0.6, Color(0.4, 0.4, 0.4))
	_generate_material("brick", 1.0, 0.2, 0.8, Color(0.6, 0.3, 0.2))
	_generate_material("metal", 2.0, 0.8, 0.2, Color(0.3, 0.3, 0.35))
	_generate_material("wood", 0.8, 0.1, 0.9, Color(0.4, 0.25, 0.15))
	_generate_material("asphalt", 0.3, 0.1, 0.9, Color(0.2, 0.2, 0.2))
	_generate_material("grass", 0.4, 0.05, 0.9, Color(0.2, 0.5, 0.15))
	_generate_material("sandbag", 0.7, 0.1, 0.9, Color(0.6, 0.55, 0.4))
	
	print("Material generation complete.")
	quit()

func _generate_material(mat_name: String, noise_scale: float, metallic: float, roughness: float, base_color: Color):
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = hash(mat_name)
	noise.frequency = 0.05 * noise_scale
	if mat_name == "wood":
		noise.noise_type = FastNoiseLite.TYPE_VALUE
		noise.frequency = 0.1
	elif mat_name == "brick":
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		noise.frequency = 0.08
	
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.albedo_texture = tex
	mat.metallic = metallic
	mat.roughness = roughness
	
	var path = "res://Assets/textures/mat_%s.tres" % mat_name
	ResourceSaver.save(mat, path)
	print("Saved material: ", path)
