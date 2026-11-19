extends "res://tools/test_case.gd"
## Menu choices: defaults, sizes, and remembering them between runs.

const TEST_PATH := "user://test_match_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_defaults_are_the_original_game() -> void:
	var settings := MatchSettings.new()
	assert_eq(settings.pipes_per_side, 10)
	assert_eq(settings.zip_points, Lattice.ZipPoints.BEAMS)
	assert_almost_eq(settings.zip_radius(), 0.5)
	assert_true(settings.gravity)
	assert_almost_eq(settings.ball_radius(), 1.5)
	assert_almost_eq(settings.goal_radius(), 6.0)
	assert_eq(settings.grapple_mode, MatchSettings.GrappleMode.REEL)
	assert_eq(settings.venue, MatchSettings.Venue.CLASSIC)
	assert_eq(settings.match_rule, MatchSettings.MatchRule.TIMED, "a timed match")
	assert_eq(settings.time_limit_minutes, 5)
	assert_eq(settings.points_to_win, 5)


func test_every_venue_has_a_scene() -> void:
	assert_eq(MatchSettings.VENUE_SCENES.size(), MatchSettings.Venue.size())
	for path: String in MatchSettings.VENUE_SCENES:
		assert_true(ResourceLoader.exists(path), "%s should exist" % path)


func test_sizes_grow_and_orbs_are_bigger_than_beams() -> void:
	var settings := MatchSettings.new()
	var last_beam := 0.0
	var last_ball := 0.0
	var last_goal := 0.0
	for size: int in MatchSettings.Size.size():
		settings.zip_size = size as MatchSettings.Size
		settings.ball_size = size as MatchSettings.Size
		settings.goal_size = size as MatchSettings.Size
		settings.zip_points = Lattice.ZipPoints.BEAMS
		var beam := settings.zip_radius()
		settings.zip_points = Lattice.ZipPoints.ORBS
		assert_true(settings.zip_radius() > beam, "orbs should be bigger than beams")
		assert_true(beam > last_beam and settings.ball_radius() > last_ball and settings.goal_radius() > last_goal,
				"each size should be bigger than the one before")
		last_beam = beam
		last_ball = settings.ball_radius()
		last_goal = settings.goal_radius()


func test_saved_choices_load_back() -> void:
	var settings := MatchSettings.new()
	settings.pipes_per_side = 6
	settings.zip_points = Lattice.ZipPoints.ORBS
	settings.zip_size = MatchSettings.Size.LARGE
	settings.gravity = false
	settings.ball_size = MatchSettings.Size.SMALL
	settings.goal_size = MatchSettings.Size.LARGE
	settings.grapple_mode = MatchSettings.GrappleMode.SWING
	settings.venue = MatchSettings.Venue.SNOW
	settings.match_rule = MatchSettings.MatchRule.POINTS
	settings.time_limit_minutes = 12
	settings.points_to_win = 7
	assert_eq(settings.save(TEST_PATH), OK)
	var loaded := MatchSettings.load_saved(TEST_PATH)
	assert_eq(loaded.pipes_per_side, 6)
	assert_eq(loaded.zip_points, Lattice.ZipPoints.ORBS)
	assert_eq(loaded.zip_size, MatchSettings.Size.LARGE)
	assert_false(loaded.gravity)
	assert_eq(loaded.ball_size, MatchSettings.Size.SMALL)
	assert_eq(loaded.goal_size, MatchSettings.Size.LARGE)
	assert_eq(loaded.grapple_mode, MatchSettings.GrappleMode.SWING)
	assert_eq(loaded.venue, MatchSettings.Venue.SNOW)
	assert_eq(loaded.match_rule, MatchSettings.MatchRule.POINTS)
	assert_eq(loaded.time_limit_minutes, 12, "the unused rule's number is remembered too")
	assert_eq(loaded.points_to_win, 7)


func test_no_saved_file_gives_the_defaults() -> void:
	var loaded := MatchSettings.load_saved("user://no_such_settings_file.cfg")
	assert_eq(loaded.pipes_per_side, 10)
	assert_eq(loaded.zip_points, Lattice.ZipPoints.BEAMS)


func test_bad_saved_values_fall_back_to_the_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(MatchSettings.SECTION, "pipes_per_side", 7)
	config.set_value(MatchSettings.SECTION, "zip_points", 5)
	config.set_value(MatchSettings.SECTION, "zip_size", -1)
	config.set_value(MatchSettings.SECTION, "gravity", "yes")
	config.set_value(MatchSettings.SECTION, "ball_size", 2)
	config.set_value(MatchSettings.SECTION, "goal_size", 1.5)
	config.set_value(MatchSettings.SECTION, "grapple_mode", 2)
	config.set_value(MatchSettings.SECTION, "venue", MatchSettings.Venue.size())
	config.set_value(MatchSettings.SECTION, "match_rule", MatchSettings.MatchRule.size())
	config.set_value(MatchSettings.SECTION, "time_limit_minutes", MatchSettings.MAX_MINUTES + 1)
	config.set_value(MatchSettings.SECTION, "points_to_win", 0)
	config.save(TEST_PATH)
	var loaded := MatchSettings.load_saved(TEST_PATH)
	assert_eq(loaded.pipes_per_side, 10)
	assert_eq(loaded.zip_points, Lattice.ZipPoints.BEAMS)
	assert_eq(loaded.zip_size, MatchSettings.Size.SMALL)
	assert_true(loaded.gravity)
	assert_eq(loaded.ball_size, MatchSettings.Size.LARGE, "a valid value is kept")
	assert_eq(loaded.goal_size, MatchSettings.Size.MEDIUM)
	assert_eq(loaded.grapple_mode, MatchSettings.GrappleMode.REEL)
	assert_eq(loaded.venue, MatchSettings.Venue.CLASSIC)
	assert_eq(loaded.match_rule, MatchSettings.MatchRule.TIMED)
	assert_eq(loaded.time_limit_minutes, 5)
	assert_eq(loaded.points_to_win, 5)


func test_numbers_of_the_wrong_type_fall_back_too() -> void:
	var config := ConfigFile.new()
	config.set_value(MatchSettings.SECTION, "time_limit_minutes", 10.0)
	config.set_value(MatchSettings.SECTION, "points_to_win", "3")
	config.save(TEST_PATH)
	var loaded := MatchSettings.load_saved(TEST_PATH)
	assert_eq(loaded.time_limit_minutes, 5)
	assert_eq(loaded.points_to_win, 5)


func test_the_limits_themselves_are_valid() -> void:
	var config := ConfigFile.new()
	config.set_value(MatchSettings.SECTION, "time_limit_minutes", MatchSettings.MAX_MINUTES)
	config.set_value(MatchSettings.SECTION, "points_to_win", MatchSettings.MIN_POINTS)
	config.save(TEST_PATH)
	var loaded := MatchSettings.load_saved(TEST_PATH)
	assert_eq(loaded.time_limit_minutes, MatchSettings.MAX_MINUTES)
	assert_eq(loaded.points_to_win, MatchSettings.MIN_POINTS)
