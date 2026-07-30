extends VBoxContainer

func _ready():
	PlayerStats.player_killed.connect(_on_player_killed)

func _on_player_killed(killer: String, victim: String, weapon: String):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "%s 🗡️ %s [%s]" % [killer, victim, weapon]
	panel.add_child(label)
	add_child(panel)
	
	# Slide in animation
	panel.position.x = 200
	var tween = create_tween()
	tween.tween_property(panel, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if get_child_count() > 4:
		get_child(0).queue_free()
		
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		if is_instance_valid(panel):
			var fade = create_tween()
			fade.tween_property(panel, "modulate:a", 0.0, 0.5)
			fade.tween_callback(panel.queue_free)
	)
