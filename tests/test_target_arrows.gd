extends "res://tools/test_case.gd"
## HUD arrows: when a target gets a marker or an edge arrow, and where the arrow goes.

const RECT := Rect2(0, 0, 1280, 720)
const MARGIN := TargetArrows.EDGE_MARGIN

var camera: Camera3D


func before_each() -> void:
	# A viewport of known size, so results don't depend on the (tiny) headless window.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RECT.size)
	add_to_tree(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	camera.global_transform = Transform3D.IDENTITY # At the origin, looking along -Z.


func _view_rect() -> Rect2:
	return camera.get_viewport().get_visible_rect()


func test_tiny_screen_shrinks_the_margin() -> void:
	# With the full 48 px margin, a 64 px screen's inner rect would be inside out (an engine
	# error). The margin shrinks to 16 px instead, so the arrow lands 16 px from the edge.
	var placement := TargetArrows.place(camera, Rect2(0, 0, 64, 64), Vector3(0, -1, -10))
	assert_false(placement.in_view)
	assert_almost_eq(placement.point, Vector2(32, 48))


func test_screen_direction_points_the_way_to_turn() -> void:
	assert_almost_eq(TargetArrows.screen_direction(Vector3(1, 0, -5)), Vector2.RIGHT)
	assert_almost_eq(TargetArrows.screen_direction(Vector3(0, 1, -5)), Vector2.UP)
	assert_almost_eq(TargetArrows.screen_direction(Vector3(-1, 0, 5)), Vector2.LEFT, 0.001, "behind and to the left")
	assert_almost_eq(TargetArrows.screen_direction(Vector3(0, 0, 5)), Vector2.DOWN, 0.001, "straight behind")


func test_edge_point_stays_inside_the_margin() -> void:
	assert_almost_eq(TargetArrows.edge_point(RECT, Vector2.RIGHT, MARGIN), Vector2(1280 - MARGIN, 360))
	assert_almost_eq(TargetArrows.edge_point(RECT, Vector2.UP, MARGIN), Vector2(640, MARGIN))
	# Diagonal: the shorter (vertical) half-height limits how far it goes.
	var corner := TargetArrows.edge_point(RECT, Vector2.ONE.normalized(), MARGIN)
	assert_almost_eq(corner, Vector2(640 + 360 - MARGIN, 720 - MARGIN), 0.01)


func test_target_ahead_gets_a_marker() -> void:
	var rect := _view_rect()
	var placement := TargetArrows.place(camera, rect, Vector3(0, 0, -10))
	assert_true(placement.in_view)
	assert_almost_eq(placement.point, rect.get_center(), 0.5)


func test_target_off_to_the_side_gets_an_arrow() -> void:
	var placement := TargetArrows.place(camera, _view_rect(), Vector3(100, 0, -10))
	assert_false(placement.in_view)
	assert_almost_eq(placement.direction, Vector2.RIGHT)


func test_target_behind_gets_an_arrow_toward_it() -> void:
	var placement := TargetArrows.place(camera, _view_rect(), Vector3(-3, 1, 20))
	assert_false(placement.in_view)
	assert_true(placement.direction.x < 0.0 and placement.direction.y < 0.0,
			"behind, left and up should point up-left, got %s" % placement.direction)
