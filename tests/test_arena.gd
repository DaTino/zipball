extends "res://tools/test_case.gd"
## Arena layout for every menu choice: where goals and spawns go, and what gets built.

const ARENA_SCENE := preload("res://src/arena/arena.tscn")

var arena: Arena


func before_each() -> void:
	arena = ARENA_SCENE.instantiate() as Arena
	arena.spin_enabled = false
	add_to_tree(arena)


func _apply(grid: int, zip_points := Lattice.ZipPoints.BEAMS,
		zip_size := MatchSettings.Size.SMALL) -> MatchSettings:
	var settings := MatchSettings.new()
	settings.pipes_per_side = grid
	settings.zip_points = zip_points
	settings.zip_size = zip_size
	arena.apply_settings(settings)
	return settings


func test_cube_is_the_same_size_for_every_grid() -> void:
	for grid: int in MatchSettings.GRID_SIZES:
		_apply(grid)
		assert_almost_eq(arena.lattice.half_extent, 108.0, 0.001, "grid %d" % grid)


func test_center_is_open_for_every_grid() -> void:
	for grid: int in MatchSettings.GRID_SIZES:
		_apply(grid, Lattice.ZipPoints.BEAMS, MatchSettings.Size.LARGE)
		assert_true(arena.lattice.distance_to_nearest_zip_point(Vector3.ZERO) > 10.0, "grid %d" % grid)


func test_goals_sit_in_open_cells_toward_opposite_corners() -> void:
	var biggest_goal: float = MatchSettings.GOAL_RADII.max()
	for grid: int in MatchSettings.GRID_SIZES:
		_apply(grid)
		var own := arena.goal_local_position(0)
		var theirs := arena.goal_local_position(1)
		assert_almost_eq(own, -theirs, 0.001, "grid %d: mirror images" % grid)
		assert_true(theirs.x > 0.0 and is_equal_approx(theirs.x, theirs.y) and is_equal_approx(theirs.x, theirs.z),
				"grid %d: on the diagonal, got %s" % [grid, theirs])
		assert_true(own.distance_to(theirs) > 180.0, "grid %d: far apart" % grid)
		assert_true(arena.lattice.distance_to_nearest_zip_point(theirs) > biggest_goal + 2.0,
				"grid %d: a large goal clears the beams" % grid)


func test_spawns_are_between_the_ball_and_their_own_goal() -> void:
	for grid: int in MatchSettings.GRID_SIZES:
		_apply(grid, Lattice.ZipPoints.BEAMS, MatchSettings.Size.LARGE)
		for team: int in 2:
			var spawn := arena.spawn_local_position(team)
			var goal := arena.goal_local_position(team)
			var label := "grid %d, team %d" % [grid, team]
			assert_true(spawn.dot(goal) > 0.0, label + ": on their own side")
			assert_true(spawn.length() > 20.0 and spawn.length() < goal.length(),
					label + ": between the center and the goal")
			assert_true(arena.lattice.distance_to_nearest_zip_point(spawn) > 10.0, label + ": in open space")


func test_beams_are_solid_and_orbs_are_not() -> void:
	_apply(6, Lattice.ZipPoints.BEAMS)
	assert_eq(arena.get_shape_owners().size(), 3 * 6 * 6)
	_apply(6, Lattice.ZipPoints.ORBS)
	assert_eq(arena.get_shape_owners().size(), 0, "nothing bumps into orbs")
	var orbs := arena.find_child("Orbs", true, false) as MultiMeshInstance3D
	assert_not_null(orbs)
	if orbs != null:
		assert_eq(orbs.multimesh.instance_count, 6 * 6 * 6)


func test_rebuilding_replaces_the_old_geometry() -> void:
	_apply(4, Lattice.ZipPoints.BEAMS)
	_apply(8, Lattice.ZipPoints.ORBS)
	_apply(10, Lattice.ZipPoints.BEAMS)
	assert_eq(arena.get_child_count(), 1, "only the newest geometry should be left")
	assert_null(arena.find_child("Orbs", true, false))
	var pipes := arena.find_child("Pipes", true, false) as MultiMeshInstance3D
	assert_eq(pipes.multimesh.instance_count, 300)
	assert_eq(arena.get_shape_owners().size(), 300)


func test_sizes_follow_the_settings() -> void:
	var settings := _apply(10, Lattice.ZipPoints.BEAMS, MatchSettings.Size.MEDIUM)
	assert_almost_eq(arena.zip_radius, 1.0)
	var shape := arena.shape_owner_get_shape(arena.get_shape_owners()[0], 0) as CylinderShape3D
	assert_almost_eq(shape.radius, 1.0)
	settings.goal_size = MatchSettings.Size.LARGE
	arena.apply_settings(settings)
	var goal := arena.find_child("Goal0", true, false) as MeshInstance3D
	assert_almost_eq((goal.mesh as SphereMesh).radius, 9.0)
