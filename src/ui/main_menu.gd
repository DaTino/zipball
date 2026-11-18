class_name MainMenu
extends Node3D
## The main menu: match settings and a Start Game! button, over a live preview of the arena
## the settings make. It remembers the last choices (MatchSettings.save()). In a match,
## M comes back here.

const MATCH_SCENE := preload("res://src/match/match.tscn")
const SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]
## The preview camera looks at the cube's center from here.
const CAMERA_POSITION := Vector3(260, 150, 330)
## Shifts the view so the cube sits to the right of the settings panel (m, camera space).
const CAMERA_SHIFT := -200.0

const PANEL_COLOR := Color(0.05, 0.08, 0.22, 0.88)
const PANEL_EDGE := Color(0.45, 0.65, 1.0, 0.6)
const LABEL_COLOR := Color(0.78, 0.87, 1.0)
const DARK_TEXT := Color(0.08, 0.08, 0.16)
const START_COLOR := Color(1.0, 0.5, 0.1)

## Off in tests, so they don't read or overwrite the player's saved choices.
@export var remember_settings := true

var settings: MatchSettings
var start_button: Button
## The venue shown behind the menu: swapped whenever the Environment choice changes.
var scenery: Scenery

@onready var _arena: Arena = %Arena
@onready var _ball: Ball = %Ball
@onready var _camera: Camera3D = %Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings = MatchSettings.load_saved() if remember_settings else MatchSettings.new()
	_ball.reset_to(_arena.global_position)
	_camera.look_at_from_position(CAMERA_POSITION, Vector3.ZERO)
	_camera.h_offset = CAMERA_SHIFT
	_build_ui()
	_refresh_preview()
	start_button.grab_focus()


## The preview tumbles like a real match. This is presentation only (nothing is scored here),
## so the menu steps the arena itself.
func _physics_process(delta: float) -> void:
	_arena.step(delta)


func start_game() -> void:
	if remember_settings:
		settings.save()
	get_tree().change_scene_to_node(build_match())


## A match set up with the chosen settings, not yet in the tree.
func build_match() -> Match:
	var match_node := MATCH_SCENE.instantiate() as Match
	match_node.settings = settings.duplicate() as MatchSettings
	return match_node


func _refresh_preview() -> void:
	var venue_scene := MatchSettings.VENUE_SCENES[settings.venue]
	if scenery == null or scenery.scene_file_path != venue_scene:
		if scenery != null:
			remove_child(scenery)
			scenery.queue_free()
		scenery = settings.make_scenery()
		add_child(scenery)
		move_child(scenery, 0)
		scenery.use_as_preview()
	_arena.apply_settings(settings, scenery)
	_ball.radius = settings.ball_radius()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := MarginContainer.new()
	screen.theme = _make_theme()
	screen.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	screen.add_theme_constant_override("margin_left", 40)
	screen.add_theme_constant_override("margin_top", 20)
	screen.add_theme_constant_override("margin_bottom", 20)
	layer.add_child(screen)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	screen.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "ZIPBALL"
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 9)
	column.add_child(grid)

	var grid_names: Array[String] = []
	for count: int in MatchSettings.GRID_SIZES:
		grid_names.append(str(count))
	_add_choice(grid, "Grid Dimension", grid_names, MatchSettings.GRID_SIZES.find(settings.pipes_per_side),
			func(i: int) -> void: settings.pipes_per_side = MatchSettings.GRID_SIZES[i])
	_add_choice(grid, "Zip Points", ["Beams", "Orbs"], settings.zip_points,
			func(i: int) -> void: settings.zip_points = i as Lattice.ZipPoints)
	_add_choice(grid, "Zip Point Size", SIZE_NAMES, settings.zip_size,
			func(i: int) -> void: settings.zip_size = i as MatchSettings.Size)
	_add_choice(grid, "Gravity", ["Off", "On"], 1 if settings.gravity else 0,
			func(i: int) -> void: settings.gravity = i == 1)
	_add_choice(grid, "Ball Size", SIZE_NAMES, settings.ball_size,
			func(i: int) -> void: settings.ball_size = i as MatchSettings.Size)
	_add_choice(grid, "Goal Size", SIZE_NAMES, settings.goal_size,
			func(i: int) -> void: settings.goal_size = i as MatchSettings.Size)
	_add_choice(grid, "Grapple", ["Reel", "Swing"], settings.grapple_mode,
			func(i: int) -> void: settings.grapple_mode = i as MatchSettings.GrappleMode)
	_add_choice(grid, "Environment", ["Classic", "Space", "Snow", "Lava", "Desert"], settings.venue,
			func(i: int) -> void: settings.venue = i as MatchSettings.Venue)

	start_button = Button.new()
	start_button.name = "StartGame"
	start_button.text = "Start Game!"
	start_button.theme_type_variation = &"StartButton"
	start_button.custom_minimum_size = Vector2(0, 58)
	start_button.pressed.connect(start_game)
	column.add_child(start_button)

	var hint := Label.new()
	hint.text = "In a match, press M to come back here."
	hint.theme_type_variation = &"Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## One setting: a label, then a row of buttons where exactly one is lit. Picking one calls
## `on_pick` with its index and updates the preview. Buttons are named after the setting
## and choice ("ZipPointsOrbs"), so tests can find them.
func _add_choice(grid: GridContainer, title: String, choices: Array[String], selected: int,
		on_pick: Callable) -> void:
	var label := Label.new()
	label.text = title
	grid.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	grid.add_child(row)
	var group := ButtonGroup.new()
	for i: int in choices.size():
		var button := Button.new()
		button.name = (title + choices[i]).replace(" ", "")
		button.text = choices[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == selected
		button.custom_minimum_size = Vector2(84, 38)
		button.pressed.connect(func() -> void:
			on_pick.call(i)
			_refresh_preview())
		row.add_child(button)


## Bright, chunky, Dreamcast-era: a dark blue panel, ball-yellow for the lit choice, and an
## orange Start button.
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_COLOR, PANEL_EDGE, 18, 24))

	theme.set_color("font_color", "Label", LABEL_COLOR)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("outline_size", "Label", 4)

	theme.set_type_variation(&"Title", &"Label")
	theme.set_font_size("font_size", "Title", 60)
	theme.set_color("font_color", "Title", Ball.COLOR)
	theme.set_color("font_outline_color", "Title", Color(0.02, 0.04, 0.14))
	theme.set_constant("outline_size", "Title", 14)

	theme.set_type_variation(&"Hint", &"Label")
	theme.set_font_size("font_size", "Hint", 16)
	theme.set_color("font_color", "Hint", Color(LABEL_COLOR, 0.7))

	theme.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.22)))
	theme.set_stylebox("hover", "Button", _box(Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.5)))
	theme.set_stylebox("pressed", "Button", _box(Ball.COLOR, Ball.COLOR.lightened(0.4)))
	theme.set_stylebox("hover_pressed", "Button", _box(Ball.COLOR.lightened(0.2), Color.WHITE))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", DARK_TEXT)
	theme.set_color("font_hover_pressed_color", "Button", DARK_TEXT)

	theme.set_type_variation(&"StartButton", &"Button")
	theme.set_font_size("font_size", "StartButton", 28)
	theme.set_stylebox("normal", "StartButton", _box(START_COLOR, Ball.COLOR, 12, 8, 4))
	theme.set_stylebox("hover", "StartButton", _box(START_COLOR.lightened(0.15), Color.WHITE, 12, 8, 4))
	theme.set_stylebox("pressed", "StartButton", _box(START_COLOR.darkened(0.2), Color.WHITE, 12, 8, 4))
	theme.set_color("font_color", "StartButton", Color.WHITE)
	theme.set_color("font_hover_color", "StartButton", Color.WHITE)
	theme.set_color("font_focus_color", "StartButton", Color.WHITE)
	theme.set_color("font_pressed_color", "StartButton", Color.WHITE)
	theme.set_color("font_outline_color", "StartButton", Color(0.35, 0.1, 0.0))
	theme.set_constant("outline_size", "StartButton", 8)
	return theme


func _box(fill: Color, edge: Color, radius := 8, padding := 8, border := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box


## A white outline around whichever button has keyboard or gamepad focus.
func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0), Color.WHITE, 10, 8, 3)
	box.draw_center = false
	box.set_expand_margin_all(3)
	return box
