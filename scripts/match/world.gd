extends Node3D

@onready var police_spawns = $Spawns/Police.get_children()
@onready var terrorist_spawns = $Spawns/Terrorist.get_children()

var player_scene = preload("res://scenes/player/player.tscn")
var bot_scene = preload("res://scenes/player/player.tscn")

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
	MatchManager.round_state_changed.connect(_on_round_state_changed)
	MatchManager.match_ended.connect(_on_match_ended)
	
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
	if not OS.has_feature("web"):
		env.ssao_enabled = true
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.02
		env.volumetric_fog_albedo = Color(0.6, 0.7, 0.8)
	
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	if not OS.has_feature("web"):
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
		r_mesh.size = 0.03
		r_mesh.sections = 2
		r_mesh.section_length = 0.6
		
		var r_smat = StandardMaterial3D.new()
		r_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_smat.albedo_color = Color(0.7, 0.8, 0.9, 0.3)
		r_smat.emission_enabled = true
		r_smat.emission = Color(0.6, 0.7, 0.8)
		r_mesh.material = r_smat
		
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
	else:
		# CPUParticles for Web
		var rain = CPUParticles3D.new()
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		rain.emission_box_extents = Vector3(120, 1, 120)
		rain.direction = Vector3(0.1, -1, 0)
		rain.spread = 2.0
		rain.initial_velocity_min = 25.0
		rain.initial_velocity_max = 35.0
		rain.gravity = Vector3(0, -9.8, 0)
		
		var r_mesh = QuadMesh.new()
		r_mesh.size = Vector2(0.05, 0.8)
		var r_smat = StandardMaterial3D.new()
		r_smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_smat.albedo_color = Color(0.7, 0.8, 0.9, 0.3)
		r_smat.emission_enabled = true
		r_smat.emission = Color(0.6, 0.7, 0.8)
		r_smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		r_mesh.material = r_smat
		
		rain.mesh = r_mesh
		rain.amount = 8000
		rain.lifetime = 1.5
		rain.position = Vector3(0, 30, 0)
		add_child(rain)
	
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

func _on_match_ended(winner: int):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		var winner_str = "POLICE" if winner == Team.TeamId.POLICE else "TERRORISTS"
		hud._show_banner("MATCH OVER: " + winner_str + " WINS!", Color(1.0, 0.8, 0.2))
		
	# Wait 5 seconds then reload the level
	var t = get_tree().create_timer(5.0)
	t.timeout.connect(func(): get_tree().reload_current_scene())

func _on_round_state_changed(new_state: int):
	if new_state == MatchManager.MatchState.ROUND_START:
		_reset_round()

func _reset_round():
	if not multiplayer.is_server(): return
	
	var weather = get_node_or_null("WeatherManager")
	if weather and weather.has_method("_randomize_weather"):
		weather._randomize_weather()
	
	# Clear weapon drops and bomb
	for drop in get_tree().get_nodes_in_group("weapon_drops"):
		drop.queue_free()
	for bomb in get_tree().get_nodes_in_group("bomb"):
		bomb.queue_free()
		
	var p_team = NetworkManager.local_player_team
	var local_p = get_node_or_null("1")
	if not local_p:
		_spawn_player(1, p_team)
	else:
		local_p.health = 100
		local_p.global_position = _get_random_spawn(p_team)
		local_p.rpc("sync_health", 100, local_p.armor)
		local_p.has_bomb = false
		
	var enemy_team = Team.TeamId.TERRORIST if p_team == Team.TeamId.POLICE else Team.TeamId.POLICE
	if NetworkManager.is_team_mode:
		for i in range(2, 6): _reset_bot(i, p_team)
		for i in range(6, 11): _reset_bot(i, enemy_team)
	else:
		_reset_bot(2, enemy_team)

func _reset_bot(id: int, team: Team.TeamId):
	var b_name = "Bot_" + str(id)
	var b = get_node_or_null(b_name)
	if not b:
		_spawn_bot(id, team, _get_random_spawn(team))
	else:
		b.health = 100
		b.global_position = _get_random_spawn(team)
		b.has_bomb = false

func _apply_hq_materials():
	var grass = load("res://Assets/textures/mat_grass.tres")
	if grass: grass.uv1_triplanar = true
	
	var concrete = load("res://Assets/textures/mat_concrete.tres")
	if concrete: concrete.uv1_triplanar = true
	var brick = load("res://Assets/textures/mat_brick.tres")
	if brick: brick.uv1_triplanar = true
	var metal = load("res://Assets/textures/mat_metal.tres")
	if metal: metal.uv1_triplanar = true
	
	# Apply to world geometry
	var geometry = get_node_or_null("NavigationRegion3D/MapGeometry")
	if geometry:
		geometry.material_override = null
		
		var ground = geometry.get_node_or_null("Ground")
		if ground:
			ground.material = grass
			if grass is StandardMaterial3D and grass.albedo_texture == null:
				# It's a noise texture, let's add blade-scale detail with noise scale
				var noise = FastNoiseLite.new()
				noise.frequency = 0.5 # High frequency for blades
				var tex = NoiseTexture2D.new()
				tex.noise = noise
				tex.width = 512
				tex.height = 512
				tex.seamless = true
				grass.albedo_texture = tex
				grass.uv1_scale = Vector3(20, 20, 20)
				grass.albedo_color = Color(0.2, 0.4, 0.1) # Darker green
		
		var bA = geometry.get_node_or_null("BuildingA")
		if bA:
			var posA = bA.position
			bA.queue_free()
			_build_modular_compound(geometry, posA, brick, metal, "BombSiteA")
			
		var bB = geometry.get_node_or_null("BuildingB")
		if bB:
			var posB = bB.position
			bB.queue_free()
			_build_modular_compound(geometry, posB, brick, metal, "BombSiteB")
			
		var center = geometry.get_node_or_null("CenterStructure")
		if center: center.material = metal

func _build_modular_compound(parent: Node, pos: Vector3, wall_mat: Material, floor_mat: Material, site_name: String):
	var combiner = CSGCombiner3D.new()
	combiner.position = pos
	combiner.use_collision = true
	parent.add_child(combiner)
	
	# Main Building Shell (Hollow Box)
	var shell = CSGBox3D.new()
	shell.size = Vector3(15, 8, 10)
	shell.position = Vector3(0, 4, 0)
	shell.material = wall_mat
	combiner.add_child(shell)
	
	var hollow = CSGBox3D.new()
	hollow.size = Vector3(14.5, 7.5, 9.5)
	hollow.position = Vector3(0, 4, 0)
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(hollow)
	
	# Second floor slab
	var floor2 = CSGBox3D.new()
	floor2.size = Vector3(15, 0.5, 10)
	floor2.position = Vector3(0, 4, 0)
	floor2.material = floor_mat
	combiner.add_child(floor2)
	
	# Stairwell cutout in floor2
	var stair_hole = CSGBox3D.new()
	stair_hole.size = Vector3(3, 2, 4)
	stair_hole.position = Vector3(-5, 4, -2)
	stair_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(stair_hole)
	
	# Stairs (simple ramp)
	var ramp = CSGPolygon3D.new()
	ramp.polygon = PackedVector2Array([Vector2(0,0), Vector2(4, 4), Vector2(4, 0)])
	ramp.depth = 2.0
	ramp.position = Vector3(-6, 0, -1)
	ramp.rotation_degrees.y = -90
	ramp.material = floor_mat
	combiner.add_child(ramp)
	
	# Doors on ground floor
	var door1 = CSGBox3D.new()
	door1.size = Vector3(2, 3, 2)
	door1.position = Vector3(0, 1.5, 5)
	door1.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(door1)
	
	var door2 = CSGBox3D.new()
	door2.size = Vector3(2, 3, 2)
	door2.position = Vector3(0, 1.5, -5)
	door2.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(door2)
	
	# Windows on ground floor
	var win1 = CSGBox3D.new()
	win1.size = Vector3(3, 1.5, 2)
	win1.position = Vector3(4, 1.5, 5)
	win1.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(win1)
	
	var win2 = CSGBox3D.new()
	win2.size = Vector3(3, 1.5, 2)
	win2.position = Vector3(-4, 1.5, 5)
	win2.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(win2)
	
	# Windows on second floor
	var win3 = CSGBox3D.new()
	win3.size = Vector3(4, 2, 2)
	win3.position = Vector3(0, 5.5, 5)
	win3.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(win3)
	
	# Bomb Site Area
	var site = Area3D.new()
	site.name = site_name
	site.set_script(load("res://scripts/match/bomb_site.gd"))
	site.position = pos + Vector3(0, 1, 0)
	var site_col = CollisionShape3D.new()
	site_col.shape = BoxShape3D.new()
	site_col.shape.size = Vector3(4, 2, 4)
	site.add_child(site_col)
	parent.add_child(site)
	
	# Add some cover (crates)
	for i in range(4):
		var crate = CSGBox3D.new()
		crate.size = Vector3(1.2, 1.2, 1.2)
		crate.position = pos + Vector3(randf_range(-4, 4), 0.6, randf_range(-4, 4))
		crate.material = floor_mat
		crate.use_collision = true
		parent.add_child(crate)

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
	b.is_bot = true
	
	# Add NavigationAgent3D
	var nav = NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	b.add_child(nav)
	
	# Add BotController
	var brain = Node.new()
	brain.name = "BotController"
	brain.set_script(load("res://scripts/player/bot_controller.gd"))
	b.add_child(brain)
	
	add_child(b)
	b.global_position = pos
