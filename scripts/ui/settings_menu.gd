extends Control

@onready var quality_options = $Panel/VBox/GraphicsHBox/QualityOptions
@onready var volume_slider = $Panel/VBox/AudioHBox/VolumeSlider
@onready var mute_checkbox = $Panel/VBox/MuteHBox/MuteCheckbox
@onready var close_btn = $Panel/VBox/CloseButton

func _ready():
	visible = false
	
	if quality_options:
		quality_options.clear()
		quality_options.add_item("Low")
		quality_options.add_item("Medium")
		quality_options.add_item("High")
		quality_options.add_item("Ultra")
		
		var gm = get_node_or_null("/root/GraphicsManager")
		if gm:
			quality_options.selected = gm.get_quality()
			
		quality_options.item_selected.connect(_on_quality_selected)
		
	if volume_slider:
		var am = get_node_or_null("/root/AudioManager")
		if am:
			volume_slider.value = am.master_volume
		volume_slider.value_changed.connect(_on_volume_changed)
		
	if mute_checkbox:
		var am = get_node_or_null("/root/AudioManager")
		if am:
			mute_checkbox.button_pressed = am.is_muted
		mute_checkbox.toggled.connect(_on_mute_toggled)
		
	if close_btn:
		close_btn.pressed.connect(close_menu)

func open_menu():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu():
	visible = false
	# Only capture mouse if we are in-game (World scene)
	var scene_name = get_tree().current_scene.name
	if scene_name == "World":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quality_selected(idx: int):
	var gm = get_node_or_null("/root/GraphicsManager")
	if gm:
		gm.set_quality(idx)

func _on_volume_changed(val: float):
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.set_master_volume(val)

func _on_mute_toggled(pressed: bool):
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.set_muted(pressed)
