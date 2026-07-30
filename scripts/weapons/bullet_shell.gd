extends RigidBody3D

func _ready():
	apply_impulse(Vector3(randf_range(0.5, 1.5), randf_range(1.0, 2.5), randf_range(-0.5, 0.5)))
	var t = get_tree().create_timer(3.0)
	t.timeout.connect(queue_free)
