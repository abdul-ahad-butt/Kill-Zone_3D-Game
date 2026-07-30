extends Node

class_name PVPMode

var ai_scene = preload("res://player.tscn")
var spawns_police = []
var spawns_terrorist = []

func _ready():
	var world = get_node_or_null("/root/World")
	if world:
		var sp = world.get_node_or_null("Spawns/Police")
		if sp: spawns_police = sp.get_children()
		
		var st = world.get_node_or_null("Spawns/Terrorist")
		if st: spawns_terrorist = st.get_children()
		
	# Connect to network events if not already done in network manager
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_host(port: int = 12345):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	
	_spawn_player(1, BaseCharacter.Faction.POLICE) # Host is police for example

func join_game(ip: String = "127.0.0.1", port: int = 12345):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int):
	if multiplayer.is_server():
		# Spawn new player as terrorist for example
		_spawn_player(id, BaseCharacter.Faction.TERRORIST)

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var world = get_node_or_null("/root/World")
		if world:
			var p = world.get_node_or_null(str(id))
			if p: p.queue_free()

func _spawn_player(id: int, faction: int):
	var player = ai_scene.instantiate()
	player.name = str(id)
	player.faction = faction
	
	var world = get_node_or_null("/root/World")
	if not world: return
	
	world.add_child(player)
	
	var p_spawns = spawns_police if faction == BaseCharacter.Faction.POLICE else spawns_terrorist
	if p_spawns.size() > 0:
		player.global_position = p_spawns[id % p_spawns.size()].global_position
