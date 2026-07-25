extends Control

var joystick_active: bool = false
var joystick_center: Vector2 = Vector2.ZERO
var joystick_current: Vector2 = Vector2.ZERO
var max_radius: float = 100.0

@onready var base_rect = $JoystickBase
@onready var stick_rect = $JoystickBase/Stick

func _ready():
	hide()
	if DisplayServer.is_touchscreen_available() or ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		show()
		
	base_rect.hide()

func _input(event):
	if not visible: return
	
	if event is InputEventScreenTouch:
		if event.position.x < get_viewport_rect().size.x / 2:
			if event.pressed:
				joystick_active = true
				joystick_center = event.position
				joystick_current = event.position
				base_rect.position = joystick_center - (base_rect.size / 2.0)
				stick_rect.position = (base_rect.size / 2.0) - (stick_rect.size / 2.0)
				base_rect.show()
			else:
				if event.index == 0 or joystick_active:
					joystick_active = false
					base_rect.hide()
					_update_input(Vector2.ZERO)
	
	if event is InputEventScreenDrag and joystick_active:
		if event.position.x < get_viewport_rect().size.x / 2 or event.index == 0:
			joystick_current = event.position
			var offset = joystick_current - joystick_center
			if offset.length() > max_radius:
				offset = offset.normalized() * max_radius
				
			stick_rect.position = (base_rect.size / 2.0) - (stick_rect.size / 2.0) + offset
			
			var input_vec = offset / max_radius
			_update_input(input_vec)

func _update_input(vec: Vector2):
	if vec.x > 0.2: Input.action_press("right") 
	else: Input.action_release("right")
	
	if vec.x < -0.2: Input.action_press("left")
	else: Input.action_release("left")
	
	if vec.y > 0.2: Input.action_press("backward")
	else: Input.action_release("backward")
	
	if vec.y < -0.2: Input.action_press("forward")
	else: Input.action_release("forward")
