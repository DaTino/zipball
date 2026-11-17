class_name InputSource
extends Node
## Produces one PlayerInput per simulation tick for one player.
## Implementations: LocalInputSource (keyboard/mouse/gamepad), ScriptedInputSource (tests,
## later simple bots). A network source comes later.


## Called once per tick by Match.
func poll() -> PlayerInput:
	return PlayerInput.new()


## Sets the aim directly, e.g. after a respawn.
func set_aim(_yaw: float, _pitch: float) -> void:
	pass


## The freshest aim (yaw, pitch) for rendering. It can be newer than the last poll().
func get_live_aim() -> Vector2:
	return Vector2.ZERO
