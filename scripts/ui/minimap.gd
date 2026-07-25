extends Control

@export var camera_height: float = 30.0

@onready var sub_viewport = $SubViewportContainer/SubViewport
@onready var camera = $SubViewportContainer/SubViewport/Camera3D

var target_player: Node3D

func _ready():
	# Find local player to track
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			target_player = p
			break

func _process(_delta):
	if target_player:
		camera.global_position = target_player.global_position + Vector3(0, camera_height, 0)
	else:
		# Try to find player again if they respawned
		for p in get_tree().get_nodes_in_group("players"):
			if p.is_multiplayer_authority():
				target_player = p
				break
