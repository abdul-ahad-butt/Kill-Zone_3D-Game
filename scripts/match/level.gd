extends Node3D

@onready var players_container = $Players
@onready var spawn_police = $SpawnPolice
@onready var spawn_terrorist = $SpawnTerrorist

var player_scene = preload("res://player.tscn")

func _ready():
	if not multiplayer.is_server():
		return
		
	NetworkManager.player_connected.connect(_spawn_player)
	NetworkManager.player_disconnected.connect(_remove_player)
	
	# Spawn host if server is also a player (i.e. not headless)
	var args = OS.get_cmdline_args()
	if not "--server" in args and not "--headless" in args:
		_spawn_player(multiplayer.get_unique_id())

func _spawn_player(id: int):
	var team = MatchManager.get_auto_balanced_team(id)
	PlayerStats.register_player(id, "Player " + str(id), team)
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	if team == Team.TeamId.POLICE:
		player.global_position = spawn_police.global_position
	else:
		player.global_position = spawn_terrorist.global_position
		
	players_container.add_child(player, true)

func _remove_player(id: int):
	MatchManager.remove_player(id)
	PlayerStats.stats.erase(id)
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
