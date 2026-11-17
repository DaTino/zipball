class_name Lattice
extends RefCounted
## Geometry of the cube-shaped pipe lattice, in arena-local space (origin = cube center).
## Pure math with no nodes, so it is cheap to test and gives the same answers everywhere.
##
## Pipe indices: index / (n * n) is the axis the pipe runs along (0 = X, 1 = Y, 2 = Z).
## The remainder picks the pipe's position on the other two axes.


## Where a grapple ray met the lattice.
class Hit:
	extends RefCounted
	## Distance from the ray origin to the pipe surface (a direct hit) or to the anchor
	## (an aim-assisted hit).
	var distance := 0.0
	## Attach point on the pipe's center line, in arena-local space.
	var anchor := Vector3.ZERO
	var pipe_index := -1


var pipes_per_side: int
var spacing: float
var pipe_radius: float
## Distance from the cube center to the outermost pipe lines.
var half_extent: float


func _init(p_pipes_per_side: int = 10, p_spacing: float = 6.0, p_pipe_radius: float = 0.2) -> void:
	pipes_per_side = p_pipes_per_side
	spacing = p_spacing
	pipe_radius = p_pipe_radius
	half_extent = (pipes_per_side - 1) * spacing * 0.5


## Position of the i-th pipe line on any axis.
func coordinate(i: int) -> float:
	return -half_extent + i * spacing


## Center of an open cell. Cells are numbered 0 to pipes_per_side - 2 on each axis.
func cell_center(cell: Vector3i) -> Vector3:
	return Vector3(cell) * spacing + Vector3.ONE * (spacing * 0.5 - half_extent)


func pipe_count() -> int:
	return 3 * pipes_per_side * pipes_per_side


@warning_ignore("integer_division")
func pipe_axis(index: int) -> int:
	return index / (pipes_per_side * pipes_per_side)


## Midpoint of a pipe. The pipe runs through this point along its axis.
@warning_ignore("integer_division")
func pipe_center(index: int) -> Vector3:
	var rem := index % (pipes_per_side * pipes_per_side)
	var a := coordinate(rem / pipes_per_side)
	var b := coordinate(rem % pipes_per_side)
	var axis := pipe_axis(index)
	if axis == 0:
		return Vector3(0.0, a, b)
	elif axis == 1:
		return Vector3(a, 0.0, b)
	return Vector3(a, b, 0.0)


## Length of every pipe, end cap to end cap.
func pipe_length() -> float:
	return 2.0 * (half_extent + pipe_radius)


## Distance from a point to a pipe's center line (clamped to the pipe's ends).
func distance_to_pipe_line(point: Vector3, index: int) -> float:
	var axis := pipe_axis(index)
	var closest := pipe_center(index)
	closest[axis] = clampf(point[axis], -half_extent, half_extent)
	return point.distance_to(closest)


func distance_to_nearest_pipe(point: Vector3) -> float:
	var best := INF
	for i: int in pipe_count():
		best = minf(best, distance_to_pipe_line(point, i))
	return best


## How far a point is outside the cube (0 when inside).
func distance_outside(point: Vector3) -> float:
	var excess := point.abs() - Vector3.ONE * half_extent
	return excess.max(Vector3.ZERO).length()


## The closest point inside the cube.
func clamp_inside(point: Vector3) -> Vector3:
	return point.clamp(-Vector3.ONE * half_extent, Vector3.ONE * half_extent)


## Casts a grapple ray. The nearest pipe the ray actually hits wins. If it hits nothing,
## aim assist picks the pipe that comes closest in angle to the ray, up to `assist_angle`
## (radians) off. Because the assist is an angle, far pipes are as easy to hit as near ones.
## Only pipes within `max_distance` count. Returns null on a miss.
func raycast(origin: Vector3, direction: Vector3, max_distance: float, assist_angle: float) -> Hit:
	var dir := direction.normalized()
	var half_length := half_extent + pipe_radius
	var best: Hit = null
	for i: int in pipe_count():
		var axis := pipe_axis(i)
		var center := pipe_center(i)
		var t := _ray_cylinder(origin, dir, axis, center, pipe_radius, half_length)
		if t < 0.0 or t > max_distance:
			continue
		if best == null or t < best.distance:
			var anchor := center
			anchor[axis] = clampf(origin[axis] + dir[axis] * t, -half_extent, half_extent)
			best = _make_hit(i, t, anchor)
	if best != null or assist_angle <= 0.0:
		return best

	var best_angle := assist_angle
	for i: int in pipe_count():
		var anchor: Variant = _closest_point_on_pipe(origin, dir, i)
		if anchor == null:
			continue
		var to_anchor: Vector3 = anchor - origin
		var distance := to_anchor.length()
		if distance > max_distance or distance <= pipe_radius:
			continue
		# Angle from the ray to the pipe's near edge, not its center line.
		var angle := dir.angle_to(to_anchor) - asin(pipe_radius / distance)
		if angle < best_angle:
			best_angle = angle
			best = _make_hit(i, distance, anchor)
	return best


## The point on a pipe's center line closest to a ray (closest approach of the two lines,
## clamped to the pipe's ends), or null if the ray runs parallel to the pipe or the closest
## approach is behind the ray's origin.
func _closest_point_on_pipe(origin: Vector3, dir: Vector3, index: int) -> Variant:
	var axis := pipe_axis(index)
	var center := pipe_center(index)
	# Across the pipe, it is a point; find where the ray passes nearest to it.
	var across := Vector3.ONE
	across[axis] = 0.0
	var dir_across := dir * across
	var square := dir_across.length_squared()
	if square < 1e-9:
		return null
	var t := (center - origin).dot(dir_across) / square
	if t <= 0.0:
		return null
	var anchor := center
	anchor[axis] = clampf(origin[axis] + dir[axis] * t, -half_extent, half_extent)
	return anchor


func _make_hit(index: int, distance: float, anchor: Vector3) -> Hit:
	var hit := Hit.new()
	hit.pipe_index = index
	hit.distance = distance
	hit.anchor = anchor
	return hit


const MISSED := -1.0
const STARTED_INSIDE := -2.0


## Distance along a unit ray to an axis-aligned cylinder's surface, MISSED, or STARTED_INSIDE.
static func _ray_cylinder(origin: Vector3, dir: Vector3, axis: int, center: Vector3,
		radius: float, half_length: float) -> float:
	var offset := origin - center
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var ou: float = offset[u]
	var ov: float = offset[v]
	var du: float = dir[u]
	var dv: float = dir[v]
	var c := ou * ou + ov * ov - radius * radius
	if c <= 0.0:
		var inside_length: bool = absf(offset[axis]) <= half_length
		return STARTED_INSIDE if inside_length else MISSED
	var a := du * du + dv * dv
	if a < 1e-9:
		return MISSED # Parallel to the pipe.
	var b := ou * du + ov * dv
	var disc := b * b - a * c
	if disc < 0.0:
		return MISSED
	var t := (-b - sqrt(disc)) / a
	if t < 0.0:
		return MISSED
	var along: float = offset[axis] + dir[axis] * t
	if absf(along) > half_length:
		return MISSED
	return t
