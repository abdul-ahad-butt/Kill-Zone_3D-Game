extends Node

const PORT = 7777
const MAX_CLIENTS = 10

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()

var current_peer: MultiplayerPeer = null

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	var args = OS.get_cmdline_args()
	if "--server" in args or "--headless" in args:
		print("Starting Dedicated Server automatically...")
		host_game()

func _process(_delta):
	# WebSockets require manual polling in Godot 4
	if current_peer and current_peer is WebSocketMultiplayerPeer:
		current_peer.poll()

func host_game():
	var error = OK
	if OS.has_feature("web"):
		var peer = WebSocketMultiplayerPeer.new()
		error = peer.create_server(PORT, "0.0.0.0")
		current_peer = peer
	else:
		var peer = ENetMultiplayerPeer.new()
		error = peer.create_server(PORT, MAX_CLIENTS)
		current_peer = peer
	
	if error != OK:
		print("Failed to host Server: ", error)
		return
		
	multiplayer.multiplayer_peer = current_peer
	print("Hosting Server on port ", PORT)
	
	# Emit connected for local player (the server itself)
	_on_peer_connected(multiplayer.get_unique_id())
	
	# When hosting, change the scene to node_3d automatically
	get_tree().change_scene_to_file("res://node_3d.tscn")

func join_game(ip: String):
	var error = OK
	if OS.has_feature("web"):
		var url = ip
		if not url.begins_with("ws://") and not url.begins_with("wss://"):
			url = "ws://" + ip + ":" + str(PORT)
		var peer = WebSocketMultiplayerPeer.new()
		error = peer.create_client(url)
		current_peer = peer
		print("Joining game via WebSocket at ", url)
	else:
		var peer = ENetMultiplayerPeer.new()
		error = peer.create_client(ip, PORT)
		current_peer = peer
		print("Joining game via ENet at ", ip, ":", PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
		
	multiplayer.multiplayer_peer = current_peer
	get_tree().change_scene_to_file("res://node_3d.tscn")

func _on_peer_connected(id: int):
	print("Player connected: ", id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int):
	print("Player disconnected: ", id)
	emit_signal("player_disconnected", id)

func _on_server_disconnected():
	print("Disconnected from server")
	emit_signal("server_disconnected")
	get_tree().change_scene_to_file("res://main_menu.tscn")
