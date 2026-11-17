class_name TargetArrows
extends Control
## Points the player toward things they need to find, such as the ball and the goals.
## A target in view gets a small diamond and a label. A target out of view (off the edge or
## behind the camera) gets an arrow at the screen edge showing which way to turn.
## Presentation only: reads positions, never changes them.

## Distance (px) from the screen edge to the arrows.
const EDGE_MARGIN := 48.0
const FONT_SIZE := 14
const OUTLINE := Color(0, 0, 0, 0.8)


class Target:
	extends RefCounted
	var label: String
	var color: Color
	## Returns the target's world position for this frame (interpolated).
	var locate: Callable
	## Optional. Returns false while the target shouldn't be shown.
	var shown: Callable


## How to show one target this frame.
class Placement:
	extends RefCounted
	## True: draw a marker at `point`. False: draw an arrow at `point` (on the screen edge)
	## pointing along `direction`.
	var in_view := false
	var point := Vector2.ZERO
	var direction := Vector2.ZERO


## Height (px) kept clear at the bottom of the screen, such as for a controls hint.
var reserved_bottom := 0.0

var _targets: Array[Target] = []
## Labels drawn so far this frame, so later ones can move aside instead of overlapping.
var _label_rects: Array[Rect2] = []


func _ready() -> void:
	# Offsets too: anchors alone would keep the zero size this control had when it was added.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Adds a target. `locate` takes no arguments and returns its world position as a Vector3.
## `shown`, if given, returns false while the target should be hidden.
func track(label: String, color: Color, locate: Callable, shown := Callable()) -> void:
	var target := Target.new()
	target.label = label
	target.color = color
	target.locate = locate
	target.shown = shown
	_targets.append(target)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen_rect := Rect2(0.0, 0.0, size.x, maxf(size.y - reserved_bottom, 1.0))
	_label_rects.clear()
	for target: Target in _targets:
		if target.shown.is_valid() and not target.shown.call():
			continue
		var world: Vector3 = target.locate.call()
		var text := "%s  %d m" % [target.label, roundi(camera.global_position.distance_to(world))]
		var placement := place(camera, screen_rect, world)
		if placement.in_view:
			_draw_marker(placement.point, target.color, text)
		else:
			_draw_arrow(placement.point, placement.direction, target.color, text)


## Decides whether `world` gets a marker (in view, away from the edges) or an edge arrow.
static func place(camera: Camera3D, screen_rect: Rect2, world: Vector3) -> Placement:
	var placement := Placement.new()
	# Shrink the margin on tiny screens so the inner rect never turns inside out.
	var margin := minf(EDGE_MARGIN, minf(screen_rect.size.x, screen_rect.size.y) * 0.25)
	# The transform the camera renders with (unproject_position uses it too). It can differ
	# from global_transform while a physics-interpolated camera catches up.
	var camera_local := camera.get_camera_transform().affine_inverse() * world
	if -camera_local.z > camera.near:
		placement.point = camera.unproject_position(world)
		placement.in_view = screen_rect.grow(-margin).has_point(placement.point)
	if not placement.in_view:
		placement.direction = screen_direction(camera_local)
		placement.point = edge_point(screen_rect, placement.direction, margin)
	return placement


## Which way to turn to face a point given in the camera's local space, as a unit vector in
## screen space (x right, y down). Works for points behind the camera too.
static func screen_direction(camera_local: Vector3) -> Vector2:
	var direction := Vector2(camera_local.x, -camera_local.y)
	if direction.length_squared() < 0.000001:
		return Vector2.DOWN # Straight behind: any direction works, so point down.
	return direction.normalized()


## Where a ray from the center of `rect` along `direction` meets the rect shrunk by `margin`.
static func edge_point(rect: Rect2, direction: Vector2, margin: float) -> Vector2:
	var inner := rect.grow(-margin)
	var half := inner.size * 0.5
	var reach := INF
	if absf(direction.x) > 0.0001:
		reach = minf(reach, half.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		reach = minf(reach, half.y / absf(direction.y))
	return inner.get_center() + direction * reach


func _draw_marker(center: Vector2, color: Color, text: String) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7),
		center + Vector2(-7, 0), center + Vector2(0, -7),
	])
	draw_polyline(points, OUTLINE, 4.0)
	draw_polyline(points, color, 2.0)
	_draw_label(center + Vector2(0, -20), color, text, Vector2.UP)


func _draw_arrow(point: Vector2, direction: Vector2, color: Color, text: String) -> void:
	var side := Vector2(-direction.y, direction.x)
	var tip := point + direction * 14.0
	var back := point - direction * 8.0
	var triangle := PackedVector2Array([tip, back + side * 10.0, back - side * 10.0])
	draw_colored_polygon(triangle, color)
	triangle.append(tip)
	draw_polyline(triangle, OUTLINE, 2.0)
	# Put the label just inside the arrow, toward the screen center.
	var text_size := _text_size(text)
	var inset := 14.0 + text_size.x * 0.5 * absf(direction.x) + text_size.y * 0.5 * absf(direction.y)
	# If it overlaps another label, move it toward the screen's vertical middle.
	var nudge := Vector2.UP if direction.y > 0.1 else Vector2.DOWN
	_draw_label(point - direction * inset, color, text, nudge)


## Draws `text` centered on `center`, with a dark outline. If it would overlap a label
## already drawn this frame, it moves along `nudge` one line at a time until it doesn't.
func _draw_label(center: Vector2, color: Color, text: String, nudge: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var text_size := _text_size(text)
	var rect := Rect2(center - text_size * 0.5, text_size)
	for _attempt: int in 6:
		var overlaps := _label_rects.any(func(other: Rect2) -> bool: return other.intersects(rect))
		if not overlaps:
			break
		rect.position += nudge * (text_size.y + 2.0)
	_label_rects.append(rect)
	center = rect.get_center()
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(FONT_SIZE) - text_size.y * 0.5)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 5, OUTLINE)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)


func _text_size(text: String) -> Vector2:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
