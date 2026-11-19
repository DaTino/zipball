class_name NumberStepper
extends HBoxContainer
## A whole number between - and + buttons, kept from `low` to `high`. Any device can press the
## buttons. A mouse can also click the number and type a new one (Enter or clicking away
## applies it). Keyboard and gamepad focus skip the text field, so they never get stuck
## editing text; they use the buttons.

signal value_changed(value: int)

var low := 1
var high := 99
var value := 1
## While false, the number is dimmed and nothing changes it.
var editable := true:
	set(enabled):
		editable = enabled
		_refresh()

var _down: Button
var _field: LineEdit
var _up: Button


func _init() -> void:
	add_theme_constant_override("separation", 2)
	_down = _make_button("Down", "−", -1)
	_field = LineEdit.new()
	_field.name = "Field"
	_field.focus_mode = Control.FOCUS_CLICK
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.select_all_on_focus = true
	_field.max_length = 3
	_field.add_theme_constant_override("minimum_character_width", 2)
	_field.custom_minimum_size = Vector2(44, 0)
	_field.text_submitted.connect(func(_text: String) -> void: _apply_typed())
	_field.focus_exited.connect(_apply_typed)
	add_child(_field)
	_up = _make_button("Up", "+", 1)
	_refresh()


## Sets the range and the number without emitting value_changed.
func setup(p_low: int, p_high: int, p_value: int) -> void:
	low = p_low
	high = p_high
	value = clampi(p_value, low, high)
	_refresh()


## Changes the number, kept within the range, and emits value_changed if it changed.
func set_number(new_value: int) -> void:
	new_value = clampi(new_value, low, high)
	if new_value != value:
		value = new_value
		value_changed.emit(value)
	_refresh()


func _make_button(node_name: String, text: String, step: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(26, 0)
	button.pressed.connect(func() -> void: set_number(value + step))
	add_child(button)
	return button


## Whatever was typed, if it's a whole number; otherwise the old number comes back.
func _apply_typed() -> void:
	var text := _field.text.strip_edges()
	if editable and text.is_valid_int():
		set_number(text.to_int())
	else:
		_refresh()


func _refresh() -> void:
	_field.text = str(value)
	_field.editable = editable
	for button: Button in [_down, _up]:
		button.disabled = not editable
		# Disabled buttons can't take focus either, so arrows skip a number not in use.
		button.focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE
	_down.disabled = _down.disabled or value <= low
	_up.disabled = _up.disabled or value >= high
