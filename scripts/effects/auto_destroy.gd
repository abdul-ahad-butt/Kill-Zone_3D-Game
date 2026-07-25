extends CPUParticles3D

func _ready():
	emitting = true
	var timer = get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(queue_free)
