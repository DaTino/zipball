class_name LocalInputSource
extends InputSource
## Reads a local keyboard and mouse and/or a gamepad and turns them into PlayerInput.
## Aim accumulates here (mouse and right stick), so the simulation receives absolute angles.
## Bindings are listed in docs/design.md, "Controls".

@export var use_keyboard_mouse := true
## Gamepad device id, or -1 for none.
@export var joypad_id := 0
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## Radians per second at full right-stick tilt.
@export var stick_look_speed := 3.5
@export var stick_deadzone := 0.15
@export var invert_y := false

var _yaw := 0.0
var _pitch := 0.0
## Set when a click recaptures the mouse, so that click doesn't also fire the grapple.
var _ignore_mouse_buttons := false


func _ready() -> void:
	if use_keyboard_mouse:
		_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if not use_keyboard_mouse:
		return
	if event is InputEventMouseMotion and _mouse_captured():
		var motion := event as InputEventMouseMotion
		_turn(-motion.screen_relative.x * mouse_sensitivity, -motion.screen_relative.y * mouse_sensitivity)
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and not _mouse_captured():
		_capture_mouse()
		_ignore_mouse_buttons = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Stick look runs every frame so the view stays smooth at any frame rate.
	if joypad_id < 0:
		return
	var look := _read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	look *= look.length() # Gentle curve: finer control near the center.
	_turn(-look.x * stick_look_speed * delta, -look.y * stick_look_speed * delta)


func poll() -> PlayerInput:
	var input := PlayerInput.new()
	input.yaw = _yaw
	input.pitch = _pitch
	var move := Vector2.ZERO
	var reel := 0.0

	if use_keyboard_mouse:
		move.x += _key(KEY_D) - _key(KEY_A)
		move.y += _key(KEY_W) - _key(KEY_S)
		reel += _key(KEY_Q) - _key(KEY_E)
		input.respawn = Input.is_physical_key_pressed(KEY_R)
		input.toggle_gravity = Input.is_physical_key_pressed(KEY_G)
		var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if _ignore_mouse_buttons and not left and not right:
			_ignore_mouse_buttons = false
		if _mouse_captured() and not _ignore_mouse_buttons:
			input.grapple_held = left
			input.throw_held = right

	if joypad_id >= 0:
		var stick := _read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		move += Vector2(stick.x, -stick.y)
		reel += Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_LEFT)
		reel -= Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_RIGHT)
		input.grapple_held = input.grapple_held or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_LEFT_SHOULDER)
		input.throw_held = input.throw_held or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_RIGHT_SHOULDER)
		input.respawn = input.respawn or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_START)
		input.toggle_gravity = input.toggle_gravity or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_BACK)

	input.move = move.limit_length(1.0)
	input.reel = clampf(reel, -1.0, 1.0)
	return input


func set_aim(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -Movement.PITCH_LIMIT, Movement.PITCH_LIMIT)


func get_live_aim() -> Vector2:
	return Vector2(_yaw, _pitch)


func _turn(yaw_delta: float, pitch_delta: float) -> void:
	_yaw = wrapf(_yaw + yaw_delta, -PI, PI)
	var pitch_sign := -1.0 if invert_y else 1.0
	_pitch = clampf(_pitch + pitch_delta * pitch_sign, -Movement.PITCH_LIMIT, Movement.PITCH_LIMIT)


## Stick vector with a radial deadzone, rescaled so it still reaches full length.
func _read_stick(x_axis: JoyAxis, y_axis: JoyAxis) -> Vector2:
	var raw := Vector2(Input.get_joy_axis(joypad_id, x_axis), Input.get_joy_axis(joypad_id, y_axis))
	var length := raw.length()
	if length < stick_deadzone:
		return Vector2.ZERO
	var scaled := minf((length - stick_deadzone) / (1.0 - stick_deadzone), 1.0)
	return raw / length * scaled


func _key(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


func _mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _capture_mouse() -> void:
	# Don't grab the cursor during headless runs or automated screenshots.
	if DisplayServer.get_name() == "headless" or DevTools.screenshot_mode:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
