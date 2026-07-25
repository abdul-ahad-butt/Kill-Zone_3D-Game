extends VBoxContainer

func _ready():
	PlayerStats.player_killed.connect(_on_player_killed)

func _on_player_killed(killer: String, victim: String, weapon: String):
	var label = Label.new()
	label.text = "%s killed %s (%s)" % [killer, victim, weapon]
	add_child(label)
	
	# Keep only the last 4 kills
	if get_child_count() > 4:
		get_child(0).queue_free()
		
	# Auto-fade out after 5 seconds
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(label): label.queue_free())
