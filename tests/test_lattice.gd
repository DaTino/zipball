extends "res://tools/test_case.gd"
## Lattice geometry and grapple ray tests (pure math, no scene).

const ASSIST := 3.0 * PI / 180.0

var lattice := Lattice.new(10, 6.0, 0.2)


func test_size_matches_design() -> void:
	assert_eq(lattice.pipe_count(), 300)
	assert_almost_eq(lattice.half_extent, 27.0)
	assert_almost_eq(lattice.coordinate(0), -27.0)
	assert_almost_eq(lattice.coordinate(9), 27.0)


func test_center_and_goal_cells_are_open_space() -> void:
	assert_almost_eq(lattice.cell_center(Vector3i(4, 4, 4)), Vector3.ZERO)
	assert_almost_eq(lattice.cell_center(Vector3i(1, 1, 1)), Vector3(-18, -18, -18))
	assert_almost_eq(lattice.cell_center(Vector3i(7, 7, 7)), Vector3(18, 18, 18))
	# A cell center is 3 m from each of its four nearest pipes on every axis: 3 * sqrt(2).
	assert_almost_eq(lattice.distance_to_nearest_pipe(Vector3.ZERO), 3.0 * sqrt(2.0), 0.001)


func test_pipe_axes_and_positions() -> void:
	assert_eq(lattice.pipe_axis(0), 0)
	assert_eq(lattice.pipe_axis(100), 1)
	assert_eq(lattice.pipe_axis(299), 2)
	assert_almost_eq(lattice.pipe_center(0), Vector3(0, -27, -27))
	assert_almost_eq(lattice.pipe_center(299), Vector3(27, 27, 0))


func test_ray_attaches_to_pipe_center_line() -> void:
	# The Z pipe through x = 3, y = 3.
	var target := Vector3(3, 3, 0)
	var hit := lattice.raycast(Vector3.ZERO, target, 35.0, ASSIST)
	assert_not_null(hit, "should hit the Z pipe at (3, 3)")
	if hit == null:
		return
	assert_almost_eq(hit.anchor, target, 0.01)
	assert_eq(lattice.pipe_axis(hit.pipe_index), 2)
	assert_almost_eq(hit.distance, target.length() - 0.2, 0.01)


func test_ray_respects_range() -> void:
	assert_eq(lattice.raycast(Vector3.ZERO, Vector3(3, 3, 0), 2.0, ASSIST), null)


func test_ray_down_an_open_corridor_misses() -> void:
	# Straight along X through cell centers, every pipe stays 3 m away.
	assert_eq(lattice.raycast(Vector3.ZERO, Vector3.RIGHT, 35.0, ASSIST), null)


func test_pipe_beside_you_does_not_catch_a_shot_aimed_away() -> void:
	# 0.5 m above the Z pipe at (3, 3), aiming up: the next pipe up should catch it.
	var hit := lattice.raycast(Vector3(3, 3.5, 0), Vector3.UP, 35.0, ASSIST)
	assert_not_null(hit, "should reach the next pipe up")
	if hit == null:
		return
	assert_almost_eq(hit.anchor, Vector3(3, 9, 0), 0.01)


func test_near_miss_snaps_to_the_closest_pipe_in_angle() -> void:
	# 4 degrees past the Z pipe at (3, 3): misses its surface, but only by about 1.3 degrees.
	var aim := Vector3(1, 1, 0).normalized().rotated(Vector3.BACK, deg_to_rad(4.0))
	assert_eq(lattice.raycast(Vector3.ZERO, aim, 35.0, 0.0), null, "no direct hit")
	var hit := lattice.raycast(Vector3.ZERO, aim, 35.0, ASSIST)
	assert_not_null(hit, "aim assist should catch it")
	if hit == null:
		return
	assert_almost_eq(hit.anchor, Vector3(3, 3, 0), 0.01)


func test_aim_assist_is_an_angle_so_far_pipes_are_catchable() -> void:
	# A sparse lattice: the Z pipe at (30, 30) is 42 m away. Aiming 2.5 degrees past it misses
	# by about 1.6 m, but only by about 2.2 degrees off its edge.
	var sparse := Lattice.new(2, 60.0, 0.2)
	var aim := Vector3(1, 1, 0).normalized().rotated(Vector3.BACK, deg_to_rad(2.5))
	assert_eq(sparse.raycast(Vector3.ZERO, aim, 80.0, deg_to_rad(2.0)), null, "2 degrees is not enough")
	var hit := sparse.raycast(Vector3.ZERO, aim, 80.0, ASSIST)
	assert_not_null(hit, "3 degrees should catch it")
	if hit == null:
		return
	assert_almost_eq(hit.anchor, Vector3(30, 30, 0), 0.01)
	assert_almost_eq(hit.distance, Vector3(30, 30, 0).length(), 0.01)


func test_outside_distance_and_clamp() -> void:
	assert_almost_eq(lattice.distance_outside(Vector3(0, 0, 30)), 3.0)
	assert_almost_eq(lattice.distance_outside(Vector3(10, -10, 5)), 0.0)
	assert_almost_eq(lattice.clamp_inside(Vector3(40, 0, -30)), Vector3(27, 0, -27))
