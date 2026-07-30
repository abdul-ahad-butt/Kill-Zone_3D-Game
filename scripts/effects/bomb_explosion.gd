extends Node3D

func _ready():
	var p = get_node_or_null("Particles")
	if p: p.emitting = true
	var p2 = get_node_or_null("Sparks")
	if p2: p2.emitting = true
	
	# Light flash
	var light = get_node_or_null("OmniLight3D")
	if light:
		var t = create_tween()
		t.tween_property(light, "light_energy", 0.0, 0.5)
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)
