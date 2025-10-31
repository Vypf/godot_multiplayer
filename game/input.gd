extends Node
class_name OnlineInput

var direction: Vector2 = Vector2.ZERO

func _process(delta):
	if not is_multiplayer_authority():
		return
	
	var device = Config.arguments.get("use_gamepad", null)
	if device != null:
		var deadzone = 0.3
		direction.x = Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		direction.y = Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)

		if direction.length() < deadzone:
			direction = Vector2.ZERO
	else:
		direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down"),
		)
