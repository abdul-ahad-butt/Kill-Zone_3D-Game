extends Node3D

@onready var police_spawns = $Spawns/Police.get_children()
@onready var terrorist_spawns = $Spawns/Terrorist.get_children()

var player_scene = preload("res://scenes/player/player.tscn")
var bot_scene = preload("res://scenes/player/bot.tscn")

func _ready():
	NetworkManager.player_connected.connect(_on_player_connected)
	
	if NetworkManager.is_offline:
		# If it's an offline game, just spawn the local player immediately
		_spawn_local_offline()

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
		# Free for all - 9 enemies
		for i in range(2, 11):
			_spawn_bot(i, enemy_team, _get_random_spawn(enemy_team))

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
