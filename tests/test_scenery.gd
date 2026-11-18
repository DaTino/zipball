extends "res://tools/test_case.gd"
## Venues: every one has a sky, a sun and zip colors, and a match or the menu builds the
## chosen one.

const MATCH_SCENE := preload("res://src/match/match.tscn")


func _make(venue: MatchSettings.Venue) -> Scenery:
	var settings := MatchSettings.new()
	settings.venue = venue
	return add_to_tree(settings.make_scenery()) as Scenery


func test_every_venue_has_a_sky_and_a_sun() -> void:
	for venue: int in MatchSettings.Venue.size():
		var scenery := _make(venue as MatchSettings.Venue)
		var label: String = MatchSettings.Venue.keys()[venue]
		assert_not_null(scenery, label + " should be a Scenery")
		if scenery == null:
			continue
		assert_not_null(scenery.world.environment, label + ": environment")
		assert_not_null(scenery.world.environment.sky, label + ": sky")
		assert_not_null(scenery.sun, label + ": sun")


func test_venues_look_different() -> void:
	var colors: Array[Color] = []
	for venue: int in MatchSettings.Venue.size():
		var color := _make(venue as MatchSettings.Venue).zip_color
		assert_false(colors.has(color), "each venue should color its zip points its own way")
		colors.append(color)


func test_snow_lava_and_desert_have_weather_floors_and_peaks() -> void:
	for venue: MatchSettings.Venue in [MatchSettings.Venue.SNOW, MatchSettings.Venue.LAVA, MatchSettings.Venue.DESERT]:
		var scenery := _make(venue)
		var label: String = MatchSettings.Venue.keys()[venue]
		assert_not_null(scenery.find_child("Weather", false, false), label + ": weather")
		assert_not_null(scenery.find_child("Floor", false, false), label + ": floor")
		var rings := scenery.find_children("*", "MountainRing", false, false)
		assert_eq(rings.size(), 1, label + ": a ring of peaks")
		if rings.size() == 1:
			var ring := rings[0] as MountainRing
			assert_eq(ring.multimesh.instance_count, ring.count)
	assert_null(_make(MatchSettings.Venue.CLASSIC).find_child("Weather", false, false),
			"Classic stays as it was")


## Zip points must stand out from both teams' goals, or a goal gets lost among the beams.
func test_zip_points_are_not_team_colored() -> void:
	for venue: int in MatchSettings.Venue.size():
		var scenery := _make(venue as MatchSettings.Venue)
		var label: String = MatchSettings.Venue.keys()[venue]
		for team_color: Color in Teams.COLORS:
			var gap := Vector3(scenery.zip_color.r - team_color.r, scenery.zip_color.g - team_color.g,
					scenery.zip_color.b - team_color.b).length()
			assert_true(gap > 0.3, "%s zip points look too much like a team color" % label)


func test_weather_follows_the_camera() -> void:
	var scenery := _make(MatchSettings.Venue.SNOW)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.global_position = Vector3(30.0, -20.0, 55.0)
	camera.make_current()
	await wait_physics_ticks(2)
	var weather := scenery.find_child("Weather", false, false) as Node3D
	assert_almost_eq(weather.global_position, camera.global_position, 0.001)


func test_preview_turns_fog_off_for_that_instance_only() -> void:
	var preview := _make(MatchSettings.Venue.SNOW)
	var in_match := _make(MatchSettings.Venue.SNOW)
	preview.use_as_preview()
	assert_false(preview.world.environment.fog_enabled)
	assert_true(in_match.world.environment.fog_enabled, "the match's copy keeps its fog")


func test_match_builds_the_chosen_venue() -> void:
	var settings := MatchSettings.new()
	settings.venue = MatchSettings.Venue.LAVA
	var match_node := MATCH_SCENE.instantiate() as Match
	match_node.settings = settings
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	assert_eq(match_node.scenery.scene_file_path, MatchSettings.VENUE_SCENES[MatchSettings.Venue.LAVA])
	assert_eq(match_node.find_children("*", "Scenery", false, false).size(), 1, "just one venue")
	assert_eq(match_node.arena.zip_color, match_node.scenery.zip_color, "zip points take the venue's color")
	assert_eq(match_node.arena.zip_glow, match_node.scenery.zip_glow)
