extends Node

const PORT = 7777
const MAX_CLIENTS = 10

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()

var current_peer: WebSocketMultiplayerPeer = null

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Parse command line arguments for headless server mode
	var args = OS.get_cmdline_args()
	if "--server" in args or "--headless" in args:
		print("Starting Dedicated Server automatically...")
		host_game()

func _process(_delta):
	# WebSockets require manual polling in Godot 4
	if current_peer:
		current_peer.poll()

func host_game():
	var peer = WebSocketMultiplayerPeer.new()
	# Create a server listening on all network interfaces (0.0.0.0)
	var error = peer.create_server(PORT, "0.0.0.0")
	
	if error != OK:
		print("Failed to host WebSocket Server: ", error)
		return
		
	current_peer = peer
	multiplayer.multiplayer_peer = current_peer
	print("Hosting WebSocket Server on port ", PORT)
	_on_peer_connected(multiplayer.get_unique_id())

func join_game(ip: String):
	# Normalize IP input
	var url = ip
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		url = "ws://" + ip + ":" + str(PORT)
		
	var peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client(url)
	
	if error != OK:
		print("Failed to connect via WebSocket: ", error)
		return
		
	current_peer = peer
	multiplayer.multiplayer_peer = current_peer
	print("Joining game at ", url)

func _on_peer_connected(id: int):
	print("Player connected: ", id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int):
	print("Player disconnected: ", id)
	emit_signal("player_disconnected", id)

func _on_server_disconnected():
	print("Disconnected from server")
	emit_signal("server_disconnected")
