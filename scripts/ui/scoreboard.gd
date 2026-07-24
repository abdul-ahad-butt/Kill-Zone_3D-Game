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
	_add_row(police_list, "POLICE", "K", "D")
	_add_row(terrorist_list, "TERRORISTS", "K", "D")
	
	for peer_id in PlayerStats.stats:
		var stat = PlayerStats.stats[peer_id]
		var container = police_list if stat["team"] == Team.TeamId.POLICE else terrorist_list
		_add_row(container, stat["name"], str(stat["kills"]), str(stat["deaths"]))

func _add_row(container: Control, col1: String, col2: String, col3: String):
	var hbox = HBoxContainer.new()
	var l1 = Label.new()
	var l2 = Label.new()
	var l3 = Label.new()
	
	l1.text = col1
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.text = col2
	l2.custom_minimum_size = Vector2(40, 0)
	l3.text = col3
	l3.custom_minimum_size = Vector2(40, 0)
	
	hbox.add_child(l1)
	hbox.add_child(l2)
	hbox.add_child(l3)
	container.add_child(hbox)
