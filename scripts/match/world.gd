extends Node3D

@onready var police_spawns = $Spawns/Police.get_children()
@onready var terrorist_spawns = $Spawns/Terrorist.get_children()

var player_scene = preload("res://scenes/player/player.tscn")
var bot_scene = preload("res://scenes/player/bot.tscn")

func _ready():
	_setup_next_gen_graphics()
	_apply_hq_materials()
	
	# Bake navmesh for bots
	var nav = get_node_or_null("NavigationRegion3D")
	if nav:
		if nav.navigation_mesh == null:
			nav.navigation_mesh = NavigationMesh.new()
		nav.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav.bake_navigation_mesh(false)
		
	NetworkManager.player_connected.connect(_on_player_connected)
	
	if NetworkManager.is_offline:
		NetworkManager.is_team_mode = true # Default to team mode for offline so AI is strictly terrorists
		# If it's an offline game, just spawn the local player immediately
		_spawn_local_offline()

func _setup_next_gen_graphics():
	# Dynamic Environment Setup
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.25, 0.3)
	sky_mat.sky_horizon_color = Color(0.35, 0.4, 0.45)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.15)
	sky_mat.ground_horizon_color = Color(0.35, 0.4, 0.45)
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	
	# Enable Volumetric Fog for the weather atmosphere
	env.ssao_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.7, 0.8)
	
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	# Rain Particle System
	var rain = GPUParticles3D.new()
	var r_mat = ParticleProcessMaterial.new()
	r_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	r_mat.emission_box_extents = Vector3(120, 1, 120)
	r_mat.direction = Vector3(0.1, -1, 0)
	r_mat.spread = 2.0
	r_mat.initial_velocity_min = 25.0
	r_mat.initial_velocity_max = 35.0
	rain.process_material = r_mat
	
	var r_mesh = RibbonTrailMesh.new()
	var r_smat = StandardMaterial3D.new()
	r_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_smat.albedo_color = Color(0.7, 0.8, 0.9, 0.3)
	r_smat.emission_enabled = true
	r_smat.emission = Color(0.6, 0.7, 0.8)
	r_mesh.material = r_smat
	r_mesh.size = 0.03
	r_mesh.sections = 2
	r_mesh.section_length = 0.6
	
	rain.draw_pass_1 = r_mesh
	rain.amount = 12000
	rain.lifetime = 1.5
	rain.visibility_aabb = AABB(Vector3(-100, -30, -100), Vector3(200, 60, 200))
	rain.position = Vector3(0, 30, 0)
	add_child(rain)
	
	# Smoke/Fog low level particles
	var smoke = GPUParticles3D.new()
	var s_mat = ParticleProcessMaterial.new()
	s_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	s_mat.emission_box_extents = Vector3(100, 2, 100)
	s_mat.gravity = Vector3(1, 0, 1)
	smoke.process_material = s_mat
	var s_mesh = QuadMesh.new()
	s_mesh.size = Vector2(10, 10)
	var s_smat = StandardMaterial3D.new()
	s_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_smat.albedo_color = Color(0.8, 0.8, 0.8, 0.1)
	s_smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	s_mesh.material = s_smat
	smoke.draw_pass_1 = s_mesh
	smoke.amount = 400
	smoke.lifetime = 10.0
	smoke.position = Vector3(0, 1, 0)
	add_child(smoke)
	
	# Thunder Timer
	var thunder_timer = Timer.new()
	thunder_timer.wait_time = randf_range(10.0, 25.0)
	thunder_timer.autostart = true
	thunder_timer.timeout.connect(_on_thunder)
	add_child(thunder_timer)
		
func _on_thunder():
	if AudioManager.thunder_sound:
		AudioManager.play_2d(AudioManager.thunder_sound)
	# Reset timer
	var timers = get_children().filter(func(c): return c is Timer)
	if timers.size() > 0:
		timers[0].wait_time = randf_range(15.0, 40.0)

func _apply_hq_materials():
	# Create a clean solid green grass material instead of blurry noise
	var grass = StandardMaterial3D.new()
	grass.albedo_color = Color(0.15, 0.35, 0.1)
	grass.roughness = 0.9
	
	var concrete = load("res://Assets/textures/mat_concrete.tres")
	if concrete: concrete.uv1_triplanar = true
	var brick = load("res://Assets/textures/mat_brick.tres")
	if brick: brick.uv1_triplanar = true
	var metal = load("res://Assets/textures/mat_metal.tres")
	if metal: metal.uv1_triplanar = true
	
	# Apply to world geometry
	var geometry = get_node_or_null("NavigationRegion3D/MapGeometry")
	if geometry:
		# Remove the global override so individual CSG objects can use their own materials
		geometry.material_override = null
		
		var ground = geometry.get_node_or_null("Ground")
		if ground: ground.material = grass
		var bA = geometry.get_node_or_null("BuildingA")
		if bA: bA.material = brick
		var bB = geometry.get_node_or_null("BuildingB")
		if bB: bB.material = brick
		var center = geometry.get_node_or_null("CenterStructure")
		if center: center.material = metal

func _on_player_connected(id: int):
	# If we are hosting a real server, we'd spawn the player here.
	if NetworkManager.is_offline: return
	if not multiplayer.is_server(): return
	
	_spawn_player(id, Team.TeamId.POLICE)

func _spawn_local_offline():
	var player_team = NetworkManager.local_player_team
	var enemy_team = Team.TeamId.TERRORIST if player_team == Team.TeamId.POLICE else Team.TeamId.POLICE
	
	_spawn_player(1, player_team)
	
	if NetworkManager.is_team_mode:
		# 4 friendly bots
		for i in range(2, 6):
			_spawn_bot(i, player_team, _get_random_spawn(player_team))
		# 5 enemy bots
		for i in range(6, 11):
			_spawn_bot(i, enemy_team, _get_random_spawn(enemy_team))
	else:
		# 1v1 Mode - 1 enemy
		_spawn_bot(2, enemy_team, _get_random_spawn(enemy_team))
			
	# Start the match timer and logic
	if multiplayer.is_server():
		MatchManager.start_match()

func _get_random_spawn(team: int) -> Vector3:
	if team == Team.TeamId.POLICE and police_spawns.size() > 0:
		return police_spawns[randi() % police_spawns.size()].global_position
	elif team == Team.TeamId.TERRORIST and terrorist_spawns.size() > 0:
		return terrorist_spawns[randi() % terrorist_spawns.size()].global_position
	return Vector3.ZERO

func _spawn_player(id: int, team: Team.TeamId):
	var p = player_scene.instantiate()
	p.name = str(id)
	p.team = team
	add_child(p)
	
	# Position at a random spawn based on team
	if team == Team.TeamId.POLICE and police_spawns.size() > 0:
		p.global_position = police_spawns[randi() % police_spawns.size()].global_position
	elif team == Team.TeamId.TERRORIST and terrorist_spawns.size() > 0:
		p.global_position = terrorist_spawns[randi() % terrorist_spawns.size()].global_position
		

func _spawn_bot(id: int, team: Team.TeamId, pos: Vector3):
	var b = bot_scene.instantiate()
	b.name = "Bot_" + str(id)
	b.team = team
	add_child(b)
	b.global_position = pos
