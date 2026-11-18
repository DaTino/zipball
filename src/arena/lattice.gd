class_name Lattice
extends RefCounted
## Geometry of the cube-shaped lattice of zip points, in arena-local space (origin = cube
## center). Zip points are either beams (pipes along all three axes) or orbs (one at every spot
## where beams would cross). Pure math with no nodes, so it is cheap to test and gives the same
## answers everywhere.
##
## Beam indices: index / (n * n) is the axis the beam runs along (0 = X, 1 = Y, 2 = Z).
## The remainder picks the beam's position on the other two axes.
## Orb indices: x * n * n + y * n + z, counting beam lines on each axis.

enum ZipPoints {
	BEAMS, ## Solid pipes along all three axes.
	ORBS, ## A sphere at every spot where beams would cross. Nothing bumps into them.
}


## Where a grapple ray met a zip point.
class Hit:
	extends RefCounted
	## Distance from the ray origin to the zip point's surface (a direct hit) or to the anchor
	## (an aim-assisted hit).
	var distance := 0.0
	## Attach point, in arena-local space: on a beam's center line, or an orb's center.
	var anchor := Vector3.ZERO
	## The beam or orb that was hit. Player uses -1 for a shot at the ball.
	var index := -1
	## True when aim assist caught it (the ray itself missed).
	var assisted := false


var pipes_per_side: int
var spacing: float
var zip_points: ZipPoints
## Beam radius, or orb radius.
var zip_radius: float
## Distance from the cube center to the outermost beam lines.
var half_extent: float


func _init(p_pipes_per_side: int = 10, p_spacing: float = 6.0, p_zip_radius: float = 0.2,
		p_zip_points: ZipPoints = ZipPoints.BEAMS) -> void:
	pipes_per_side = p_pipes_per_side
	spacing = p_spacing
	zip_radius = p_zip_radius
	zip_points = p_zip_points
	half_extent = (pipes_per_side - 1) * spacing * 0.5


## Position of the i-th beam line on any axis.
func coordinate(i: int) -> float:
	return -half_extent + i * spacing


## Center of an open cell. Cells are numbered 0 to pipes_per_side - 2 on each axis.
func cell_center(cell: Vector3i) -> Vector3:
	return Vector3(cell) * spacing + Vector3.ONE * (spacing * 0.5 - half_extent)


func pipe_count() -> int:
	return 3 * pipes_per_side * pipes_per_side


func orb_count() -> int:
	return pipes_per_side * pipes_per_side * pipes_per_side


@warning_ignore("integer_division")
func pipe_axis(index: int) -> int:
	return index / (pipes_per_side * pipes_per_side)


## Midpoint of a beam. The beam runs through this point along its axis.
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


@warning_ignore("integer_division")
func orb_center(index: int) -> Vector3:
	var n := pipes_per_side
	return Vector3(coordinate(index / (n * n)), coordinate(index / n % n), coordinate(index % n))


## Length of every beam, end cap to end cap.
func pipe_length() -> float:
	return 2.0 * (half_extent + zip_radius)


## Distance from a point to a beam's center line (clamped to the beam's ends).
func distance_to_pipe_line(point: Vector3, index: int) -> float:
	var axis := pipe_axis(index)
	var closest := pipe_center(index)
	closest[axis] = clampf(point[axis], -half_extent, half_extent)
	return point.distance_to(closest)


## Distance from a point to the nearest beam's center line or orb's center.
func distance_to_nearest_zip_point(point: Vector3) -> float:
	if zip_points == ZipPoints.ORBS:
		var nearest := Vector3.ZERO
		for axis: int in 3:
			var line := clampi(roundi((point[axis] + half_extent) / spacing), 0, pipes_per_side - 1)
			nearest[axis] = coordinate(line)
		return point.distance_to(nearest)
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


## Casts a grapple ray. The nearest zip point the ray actually hits wins. If it hits nothing,
## aim assist picks the one that comes closest in angle to the ray, up to `assist_angle`
## (radians) off. Because the assist is an angle, far zip points are as easy to hit as near
## ones. Only zip points within `max_distance` count. Returns null on a miss.
func raycast(origin: Vector3, direction: Vector3, max_distance: float, assist_angle: float) -> Hit:
	var dir := direction.normalized()
	if zip_points == ZipPoints.ORBS:
		return _raycast_orbs(origin, dir, max_distance, assist_angle)
	return _raycast_beams(origin, dir, max_distance, assist_angle)


func _raycast_beams(origin: Vector3, dir: Vector3, max_distance: float, assist_angle: float) -> Hit:
	var half_length := half_extent + zip_radius
	var best: Hit = null
	for i: int in pipe_count():
		var axis := pipe_axis(i)
		var center := pipe_center(i)
		var t := _ray_cylinder(origin, dir, axis, center, zip_radius, half_length)
		if t < 0.0 or t > max_distance:
			continue
		if best == null or t < best.distance:
			var anchor := center
			anchor[axis] = clampf(origin[axis] + dir[axis] * t, -half_extent, half_extent)
			best = _make_hit(i, t, anchor, false)
	if best != null or assist_angle <= 0.0:
		return best

	var best_angle := assist_angle
	for i: int in pipe_count():
		var anchor: Variant = _closest_point_on_pipe(origin, dir, i)
		if anchor == null:
			continue
		var to_anchor: Vector3 = anchor - origin
		var distance := to_anchor.length()
		if distance > max_distance or distance <= zip_radius:
			continue
		# Angle from the ray to the beam's near edge, not its center line.
		var angle := dir.angle_to(to_anchor) - asin(zip_radius / distance)
		if angle < best_angle:
			best_angle = angle
			best = _make_hit(i, distance, anchor, true)
	return best


## Orbs in one pass: a direct hit beats any aim-assisted one. Orbs out of range are skipped
## early, which is most of them, so this stays cheap even with 1000 orbs.
func _raycast_orbs(origin: Vector3, dir: Vector3, max_distance: float, assist_angle: float) -> Hit:
	var reach := max_distance + zip_radius
	var radius_squared := zip_radius * zip_radius
	var best: Hit = null
	var best_angle := assist_angle
	for i: int in orb_count():
		var center := orb_center(i)
		var to_center := center - origin
		var square := to_center.length_squared()
		if square > reach * reach or square <= radius_squared:
			continue
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue # Behind (or level with) the shooter.
		var miss_squared := square - along * along
		if miss_squared <= radius_squared:
			var t := along - sqrt(radius_squared - miss_squared)
			if t <= max_distance and (best == null or best.assisted or t < best.distance):
				best = _make_hit(i, t, center, false)
			continue
		if (best != null and not best.assisted) or assist_angle <= 0.0:
			continue
		var distance := sqrt(square)
		if distance > max_distance:
			continue
		# Angle from the ray to the orb's near edge, not its center.
		var angle := dir.angle_to(to_center) - asin(zip_radius / distance)
		if angle < best_angle:
			best_angle = angle
			best = _make_hit(i, distance, center, true)
	return best


## The point on a beam's center line closest to a ray (closest approach of the two lines,
## clamped to the beam's ends), or null if the ray runs parallel to the beam or the closest
## approach is behind the ray's origin.
func _closest_point_on_pipe(origin: Vector3, dir: Vector3, index: int) -> Variant:
	var axis := pipe_axis(index)
	var center := pipe_center(index)
	# Across the beam, it is a point; find where the ray passes nearest to it.
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


func _make_hit(index: int, distance: float, anchor: Vector3, assisted: bool) -> Hit:
	var hit := Hit.new()
	hit.index = index
	hit.distance = distance
	hit.anchor = anchor
	hit.assisted = assisted
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
		return MISSED # Parallel to the beam.
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
