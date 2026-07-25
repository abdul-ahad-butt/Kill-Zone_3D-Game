extends Node3D

@onready var players_container = $Players
@onready var spawn_police = $SpawnPolice
@onready var spawn_terrorist = $SpawnTerrorist

var player_scene = preload("res://player.tscn")
var bot_script = preload("res://scripts/player/bot_controller.gd")

func _ready():
	if MatchManager.match_size == MatchManager.MatchSize.SOLO:
		if has_node("BombSiteC"): get_node("BombSiteC").is_active = false
		if has_node("BombSiteD"): get_node("BombSiteD").is_active = false
		if has_node("BombSiteC"): get_node("BombSiteC").hide()
		if has_node("BombSiteD"): get_node("BombSiteD").hide()
		print("Match Size: SOLO. Active Sites: A, B")
	else:
		print("Match Size: 5v5. Active Sites: A, B, C, D")
		
	MatchManager.round_state_changed.connect(_on_round_state_changed)
		
	# Assign site names based on node names
	for child in get_children():
		if child.is_in_group("BombSite"):
			child.site_name = child.name.replace("BombSite", "")

	_setup_navmesh()

	if MatchManager.is_offline_solo:
		MatchManager.current_state = MatchManager.MatchState.ROUND_START
		MatchManager.emit_signal("round_state_changed", MatchManager.current_state)
		_setup_offline_match()
		return
		
	if not multiplayer.is_server():
		return
		
	# We no longer auto-spawn on connect, wait for request_spawn RPC
	NetworkManager.player_disconnected.connect(_remove_player)
	
	# Spawn host if server is also a player (i.e. not headless)
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not "--server" in args and not "--headless" in args:
		# Host spawns itself with its choices
		_spawn_specific_player(multiplayer.get_unique_id(), MatchManager.solo_faction, MatchManager.solo_primary_weapon.resource_path if MatchManager.solo_primary_weapon else "res://resources/weapon_data/Rifle.tres")
		
	if not multiplayer.is_server():
		if multiplayer.get_peers().is_empty():
			# Not connected yet
			multiplayer.connected_to_server.connect(_on_connected_to_server)
		else:
			_on_connected_to_server()

func _on_connected_to_server():
	var weapon_path = MatchManager.solo_primary_weapon.resource_path if MatchManager.solo_primary_weapon else "res://resources/weapon_data/Rifle.tres"
	rpc_id(1, "request_spawn", MatchManager.solo_faction, weapon_path)

func _setup_navmesh():
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "MapNavRegion"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	
	var nodes_to_reparent = []
	var floor_node = get_node_or_null("Floor")
	if floor_node: nodes_to_reparent.append(floor_node)
	
	for child in get_children():
		if child is CSGBox3D and child != floor_node:
			nodes_to_reparent.append(child)
			
	for node in nodes_to_reparent:
		remove_child(node)
		nav_region.add_child(node)
		node.owner = self
		
	# Now bake the navmesh async
	nav_region.bake_navigation_mesh(true)
	print("Baking NavMesh...")

func _get_random_spawn(base_pos: Vector3) -> Vector3:
	return base_pos + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))

func start_game(mode: int, faction: Team.TeamId):
	print("Starting Game via UI... Mode: ", mode, " Faction: ", faction)
	MatchManager.match_size = mode
	MatchManager.solo_faction = faction
	MatchManager.is_offline_solo = true
	
	if mode == 0:
		if has_node("BombSiteC"): get_node("BombSiteC").is_active = false
		if has_node("BombSiteD"): get_node("BombSiteD").is_active = false
		if has_node("BombSiteC"): get_node("BombSiteC").hide()
		if has_node("BombSiteD"): get_node("BombSiteD").hide()
		
	# MatchManager state needs to be forced since it might not be listening
	MatchManager.current_state = MatchManager.MatchState.ROUND_START
	MatchManager.emit_signal("round_state_changed", MatchManager.current_state)
	
	_setup_offline_match()

func _setup_offline_match():
	var overview = get_node_or_null("OverviewCamera")
	if overview:
		overview.current = false
		
	# Spawn human player
	_spawn_solo_player("1", MatchManager.solo_faction, false)
	
	if MatchManager.match_size == MatchManager.MatchSize.FIVE_V_FIVE:
		print("Spawning bots for 5v5 offline match...")
		var enemy_team = Team.TeamId.TERRORIST if MatchManager.solo_faction == Team.TeamId.POLICE else Team.TeamId.POLICE
		
		# 4 friendly bots
		for i in range(4):
			_spawn_solo_player("friendly_bot_" + str(i), MatchManager.solo_faction, true)
			
		# 5 enemy bots
		for i in range(5):
			_spawn_solo_player("enemy_bot_" + str(i), enemy_team, true)

func _spawn_solo_player(p_name: String, team: Team.TeamId, is_bot: bool):
	var player = player_scene.instantiate()
	player.name = p_name
	player.team = team
	player.is_bot = is_bot
	
	if not is_bot and MatchManager.solo_primary_weapon:
		player.primary_weapon = MatchManager.solo_primary_weapon
	elif is_bot:
		# Give bots a default rifle
		player.primary_weapon = preload("res://resources/weapon_data/Rifle.tres")
	
	players_container.add_child(player, true)
	
	if team == Team.TeamId.POLICE:
		player.global_position = _get_random_spawn(spawn_police.global_position)
	else:
		player.global_position = _get_random_spawn(spawn_terrorist.global_position)
		player.has_bomb = true
	
	player.on_death.connect(_on_player_died)
	
	if is_bot:
		var bot_controller = Node.new()
		bot_controller.name = "BotController"
		bot_controller.set_script(bot_script)
		player.add_child(bot_controller)
	else:
		print("Player spawned and controllable. Team: ", "Police" if team == Team.TeamId.POLICE else "Terrorist")

@rpc("any_peer", "call_remote", "reliable")
func request_spawn(faction: int, weapon_path: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_specific_player(sender_id, faction, weapon_path)

func _spawn_specific_player(id: int, team: Team.TeamId, weapon_path: String):
	PlayerStats.register_player(id, "Player " + str(id), team)
	
	var player = player_scene.instantiate()
	player.name = str(id)
	player.team = team
	
	player.on_death.connect(_on_player_died)
	
	if ResourceLoader.exists(weapon_path):
		player.primary_weapon = load(weapon_path)
		
	players_container.add_child(player, true)
	
	if team == Team.TeamId.POLICE:
		player.global_position = _get_random_spawn(spawn_police.global_position)
	else:
		player.global_position = _get_random_spawn(spawn_terrorist.global_position)
		player.has_bomb = true

func _on_round_state_changed(state: int):
	if state == MatchManager.MatchState.ROUND_START:
		PlayerStats.reset_grenades_for_round()
		_respawn_all_players()

func _respawn_all_players():
	if not MatchManager.is_offline_solo and not multiplayer.is_server(): return
	
	for child in players_container.get_children():
		child.queue_free()
		
	await get_tree().process_frame
	
	if MatchManager.is_offline_solo:
		_setup_offline_match()
	else:
		# Auto-buy for bots
		if multiplayer.is_server():
			for id in PlayerStats.stats.keys():
				if id != 1: # Bot (assuming Host is 1)
					var m = PlayerStats.stats[id].get("money", 800)
					if m >= 2700:
						PlayerStats.request_buy(id, 2700, "res://resources/weapon_data/Rifle.tres")
					elif m >= 1500:
						PlayerStats.request_buy(id, 1500, "res://resources/weapon_data/SMG.tres")
						
					m = PlayerStats.stats[id].get("money", 800)
					if m >= 1000:
						PlayerStats.request_buy(id, 1000, "item_armor")
						m = PlayerStats.stats[id].get("money", 800)
					if PlayerStats.stats[id]["team"] == Team.TeamId.POLICE and m >= 400:
						PlayerStats.request_buy(id, 400, "item_defuse_kit")
						
		for id in PlayerStats.stats.keys():
			var team = PlayerStats.stats[id]["team"]
			var wp = PlayerStats.stats[id].get("weapon_path", "res://resources/weapon_data/Pistol.tres")
			_spawn_specific_player(id, team, wp)

func _on_player_died(id: int, team: Team.TeamId, weapon_path: String):
	if MatchManager.is_offline_solo or multiplayer.is_server():
		
		if MatchManager.match_size == MatchManager.MatchSize.SOLO:
			# Start a 3-second respawn timer for Deathmatch
			await get_tree().create_timer(3.0).timeout
			
			if MatchManager.is_offline_solo:
				var is_bot = (id != 1)
				_spawn_solo_player(str(id), team, is_bot)
			else:
				# Verify player hasn't disconnected
				if PlayerStats.stats.has(id) or id == multiplayer.get_unique_id():
					_spawn_specific_player(id, team, weapon_path)
		else:
			# 5v5 Mode: No respawn! Check elimination.
			var alive_police = 0
			var alive_terrorists = 0
			for child in players_container.get_children():
				if child.health > 0:
					if child.team == Team.TeamId.POLICE:
						alive_police += 1
					else:
						alive_terrorists += 1
			MatchManager.check_elimination(alive_police, alive_terrorists)

func _remove_player(id: int):
	MatchManager.remove_player(id)
	PlayerStats.stats.erase(id)
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
