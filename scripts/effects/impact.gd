extends Node3D

func _ready():
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			
	await get_tree().create_timer(2.0).timeout
	queue_free()
