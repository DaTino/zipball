extends "res://tools/test_case.gd"
## The main menu: its choices, the live preview, and the match Start Game! builds.

const MENU_SCENE := preload("res://src/ui/main_menu.tscn")

var menu: MainMenu


func before_each() -> void:
	menu = MENU_SCENE.instantiate() as MainMenu
	menu.remember_settings = false # Don't read or overwrite the real saved choices.
	add_to_tree(menu)


func _button(button_name: String) -> Button:
	var button := menu.find_child(button_name, true, false) as Button
	assert_not_null(button, "no button named %s" % button_name)
	return button


## Clicks a choice the way a player would: it lights up, then reports the press.
func _pick(button_name: String) -> void:
	var button := _button(button_name)
	if button == null:
		return
	button.button_pressed = true
	button.pressed.emit()


func test_starts_on_the_original_game() -> void:
	for button_name: String in ["GridDimension10", "ZipPointsBeams", "ZipPointSizeSmall", "GravityOn",
			"BallSizeMedium", "GoalSizeMedium", "GrappleReel", "EnvironmentClassic"]:
		var button := _button(button_name)
		if button != null:
			assert_true(button.button_pressed, "%s should be lit" % button_name)


func test_only_one_choice_per_setting_is_lit() -> void:
	_pick("ZipPointSizeLarge")
	assert_false(_button("ZipPointSizeSmall").button_pressed)
	assert_false(_button("ZipPointSizeMedium").button_pressed)
	assert_true(_button("ZipPointSizeLarge").button_pressed)


func test_picking_choices_changes_the_settings_and_the_preview() -> void:
	for button_name: String in ["GridDimension6", "ZipPointsOrbs", "ZipPointSizeLarge", "GravityOff",
			"BallSizeSmall", "GoalSizeLarge"]:
		_pick(button_name)
	var settings := menu.settings
	assert_eq(settings.pipes_per_side, 6)
	assert_eq(settings.zip_points, Lattice.ZipPoints.ORBS)
	assert_eq(settings.zip_size, MatchSettings.Size.LARGE)
	assert_false(settings.gravity)
	assert_eq(settings.ball_size, MatchSettings.Size.SMALL)
	assert_eq(settings.goal_size, MatchSettings.Size.LARGE)

	var arena := menu.get_node(^"%Arena") as Arena
	assert_eq(arena.pipes_per_side, 6)
	assert_eq(arena.zip_points, Lattice.ZipPoints.ORBS)
	assert_almost_eq(arena.zip_radius, 3.0)
	assert_almost_eq(arena.goal_radius, 9.0)
	assert_almost_eq((menu.get_node(^"%Ball") as Ball).radius, 1.0)


func test_start_builds_a_match_with_the_chosen_settings() -> void:
	for button_name: String in ["GridDimension8", "ZipPointsOrbs", "GravityOff", "BallSizeLarge"]:
		_pick(button_name)
	var match_node := menu.build_match()
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	assert_eq(match_node.arena.pipes_per_side, 8)
	assert_eq(match_node.arena.zip_points, Lattice.ZipPoints.ORBS)
	assert_almost_eq(match_node.ball.radius, 2.5)
	assert_false(match_node.gravity_enabled)
	assert_false(match_node.ball.gravity_enabled)
	var player := match_node.add_player(ScriptedInputSource.new(), 0)
	assert_false(player.gravity_enabled)
	assert_almost_eq(player.global_position, match_node.arena.to_global(match_node.arena.spawn_local_position(0)), 0.001)

	_pick("GridDimension4")
	assert_eq(match_node.settings.pipes_per_side, 8, "the match keeps its own copy of the settings")


func test_environment_choice_swaps_the_preview() -> void:
	_pick("EnvironmentSpace")
	await wait_physics_ticks(1)
	assert_eq(menu.scenery.scene_file_path, MatchSettings.VENUE_SCENES[MatchSettings.Venue.SPACE])
	_pick("EnvironmentDesert")
	await wait_physics_ticks(1)
	assert_eq(menu.scenery.scene_file_path, MatchSettings.VENUE_SCENES[MatchSettings.Venue.DESERT])
	_pick("EnvironmentLava")
	await wait_physics_ticks(1)
	assert_eq(menu.scenery.scene_file_path, MatchSettings.VENUE_SCENES[MatchSettings.Venue.LAVA])
	assert_eq(menu.find_children("*", "Scenery", false, false).size(), 1, "the old venue should be gone")
	assert_false(menu.scenery.world.environment.fog_enabled, "no fog in the preview")
	var arena := menu.get_node(^"%Arena") as Arena
	assert_eq(arena.zip_color, menu.scenery.zip_color)


func test_swing_and_venue_carry_into_the_match() -> void:
	_pick("GrappleSwing")
	_pick("EnvironmentSnow")
	var match_node := menu.build_match()
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	assert_eq(match_node.scenery.scene_file_path, MatchSettings.VENUE_SCENES[MatchSettings.Venue.SNOW])
	var player := match_node.add_player(ScriptedInputSource.new(), 0)
	assert_false(player.auto_reel, "Swing mode: the line shouldn't reel you in")


func test_m_in_a_match_goes_back_to_the_menu() -> void:
	var match_node := menu.build_match()
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	match_node._unhandled_input(key)
	await wait_physics_ticks(2)
	var scene := tree.current_scene
	assert_true(scene is MainMenu, "should be on the menu, got %s" % scene)
	if scene != null:
		scene.free()
