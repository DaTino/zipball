class_name ScriptedInputSource
extends InputSource
## Returns whatever `next_input` holds. Tests (and later simple bots) set it between ticks.

var next_input := PlayerInput.new()


func poll() -> PlayerInput:
	return next_input.copy()


func set_aim(yaw: float, pitch: float) -> void:
	next_input.yaw = yaw
	next_input.pitch = pitch


func get_live_aim() -> Vector2:
	return Vector2(next_input.yaw, next_input.pitch)
