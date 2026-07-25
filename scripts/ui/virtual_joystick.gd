extends Control

@export var joystick_mode: int = 0 # 0 = Fixed, 1 = Dynamic
@export var action_left: String = "move_left"
@export var action_right: String = "move_right"
@export var action_up: String = "move_forward"
@export var action_down: String = "move_backward"

var touch_index: int = -1
var center: Vector2
var radius: float = 100.0
var knob_radius: float = 40.0
var output_vector: Vector2 = Vector2.ZERO

@onready var base = $Base
@onready var knob = $Base/Knob

func _ready():
	base.pivot_offset = base.size / 2
	knob.pivot_offset = knob.size / 2
	center = base.position + base.pivot_offset
	
	if not OS.has_feature("mobile"):
		# Hide on PC to avoid clutter, unless testing
		# visible = false
		pass

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			if get_global_rect().has_point(event.position):
				touch_index = event.index
				if joystick_mode == 1:
					base.global_position = event.position - base.pivot_offset
					center = event.position
				_update_joystick(event.position)
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()
			
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_joystick(event.position)

func _update_joystick(pos: Vector2):
	var dir = pos - center
	if dir.length() > radius:
		dir = dir.normalized() * radius
	
	knob.position = (base.size / 2) - knob.pivot_offset + dir
	
	output_vector = dir / radius
	
	_update_input_actions()

func _reset_joystick():
	touch_index = -1
	knob.position = (base.size / 2) - knob.pivot_offset
	output_vector = Vector2.ZERO
	
	if joystick_mode == 1:
		base.position = (size / 2) - base.pivot_offset
		center = base.position + base.pivot_offset
		
	_update_input_actions()

func _update_input_actions():
	if output_vector.x < -0.1:
		Input.action_press(action_left, abs(output_vector.x))
		Input.action_release(action_right)
	elif output_vector.x > 0.1:
		Input.action_press(action_right, abs(output_vector.x))
		Input.action_release(action_left)
	else:
		Input.action_release(action_left)
		Input.action_release(action_right)
		
	if output_vector.y < -0.1:
		Input.action_press(action_up, abs(output_vector.y))
		Input.action_release(action_down)
	elif output_vector.y > 0.1:
		Input.action_press(action_down, abs(output_vector.y))
		Input.action_release(action_up)
	else:
		Input.action_release(action_up)
		Input.action_release(action_down)
