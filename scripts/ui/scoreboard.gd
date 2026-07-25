extends Control

@onready var police_list = $HBoxContainer/PoliceContainer/VBoxContainer
@onready var terrorist_list = $HBoxContainer/TerroristContainer/VBoxContainer

func _ready():
	hide()
	PlayerStats.stats_updated.connect(_update_scoreboard)

func _input(event):
	if event.is_action_pressed("ui_focus_next"): # Default Tab key
		show()
		_update_scoreboard()
	elif event.is_action_released("ui_focus_next"):
		hide()

func _update_scoreboard():
	if not visible: return
	
	# Clear lists
	for child in police_list.get_children():
		child.queue_free()
	for child in terrorist_list.get_children():
		child.queue_free()
		
	# Add headers
	_add_row(police_list, "POLICE", "K", "D", true)
	_add_row(terrorist_list, "TERRORISTS", "K", "D", true)
	
	var p_idx = 0
	var t_idx = 0
	for peer_id in PlayerStats.stats:
		var stat = PlayerStats.stats[peer_id]
		if stat["team"] == Team.TeamId.POLICE:
			_add_row(police_list, stat["name"], str(stat["kills"]), str(stat["deaths"]), false, p_idx)
			p_idx += 1
		elif stat["team"] == Team.TeamId.TERRORIST:
			_add_row(terrorist_list, stat["name"], str(stat["kills"]), str(stat["deaths"]), false, t_idx)
			t_idx += 1

func _add_row(container: Control, col1: String, col2: String, col3: String, is_header: bool = false, row_index: int = 0):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	if is_header:
		style.bg_color = Color(0.1, 0.35, 0.8, 0.9) if col1 == "POLICE" else Color(0.8, 0.15, 0.15, 0.9)
		style.set_corner_radius_all(4)
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.6) if row_index % 2 == 0 else Color(0.15, 0.15, 0.15, 0.6)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	var l1 = Label.new()
	var l2 = Label.new()
	var l3 = Label.new()
	
	l1.text = col1
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.text = col2
	l2.custom_minimum_size = Vector2(40, 0)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l3.text = col3
	l3.custom_minimum_size = Vector2(40, 0)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_header:
		l1.add_theme_font_size_override("font_size", 20)
		l2.add_theme_font_size_override("font_size", 20)
		l3.add_theme_font_size_override("font_size", 20)
		l1.add_theme_colors_override("font_shadow_color", Color(0,0,0,1))
		
	hbox.add_child(l1)
	hbox.add_child(l2)
	hbox.add_child(l3)
	margin.add_child(hbox)
	container.add_child(panel)
