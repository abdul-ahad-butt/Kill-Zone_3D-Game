extends CanvasLayer

@onready var look_area = $LookArea
@onready var player: CharacterBody3D = null

var look_touch_index: int = -1
var look_sensitivity: float = 1.0

func _ready():
	if not DisplayServer.is_touchscreen_available() and not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		hide()
		set_process_input(false)
		return
		
	look_area.gui_input.connect(_on_look_area_gui_input)

func _process(_delta):
	if not player and get_tree().has_group("local_player"):
		player = get_tree().get_nodes_in_group("local_player")[0]

func _on_look_area_gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and look_touch_index == -1:
			look_touch_index = event.index
		elif not event.pressed and event.index == look_touch_index:
			look_touch_index = -1
			
	elif event is InputEventScreenDrag and event.index == look_touch_index:
		if player and player.has_method("_rotate_camera"):
			player._rotate_camera(event.relative * look_sensitivity)

# Action button mappings
# These buttons can be hooked up directly via their `pressed` signals in the Godot Editor,
# but we can also use Godot's built-in TouchScreenButton nodes which map directly to Input Actions!
# (See Walkthrough for setup instructions)
