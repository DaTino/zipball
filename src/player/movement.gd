class_name Movement
extends RefCounted
## Pure movement math shared by the player simulation and the tests.

## Just under 90 degrees, so the view never flips over the top.
const PITCH_LIMIT := 1.55


## First-person orientation: yaw around world up, then pitch. Forward is -Z.
static func aim_basis(yaw: float, pitch: float) -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


## Yaw and pitch (as x, y) that look along `direction`.
static func aim_toward(direction: Vector3) -> Vector2:
	var d := direction.normalized()
	return Vector2(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))


## Level forward vector for a yaw.
static func flat_forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Level right vector for a yaw.
static func flat_right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## Grapple rope as a maximum-length constraint (a rope, not a spring).
## When the player would end this tick farther than `length` from the anchor, the outward
## part of their velocity (relative to the moving anchor) is replaced by just enough inward
## speed to end the tick at `length`, capped at `max_pull_speed`. A slack rope does nothing.
static func apply_rope(position: Vector3, velocity: Vector3, anchor: Vector3,
		anchor_velocity: Vector3, length: float, delta: float, max_pull_speed: float) -> Vector3:
	var to_player := position - anchor
	var distance := to_player.length()
	if distance < 0.0001:
		return velocity
	var direction := to_player / distance
	var relative := velocity - anchor_velocity
	var radial_speed := relative.dot(direction)
	if distance + radial_speed * delta <= length:
		return velocity # Slack this tick.
	var target_radial := maxf((length - distance) / delta, -max_pull_speed)
	if radial_speed > target_radial:
		relative += direction * (target_radial - radial_speed)
	return relative + anchor_velocity


## Air control: accelerate toward `wish_direction` (unit length) without letting it push the
## speed along that direction past `max_speed`. Faster momentum is never reduced.
static func air_control(velocity: Vector3, wish_direction: Vector3, accel: float,
		max_speed: float, delta: float) -> Vector3:
	var current := velocity.dot(wish_direction)
	var add := clampf(max_speed - current, 0.0, accel * delta)
	return velocity + wish_direction * add


## Gravity inside the cube. Outside it, a pull back toward the cube replaces gravity (D6).
## Shared by the players and the ball.
static func apply_environment(velocity: Vector3, position: Vector3, arena: Arena,
		tuning: MovementTuning, gravity_on: bool, delta: float) -> Vector3:
	var outside := arena.distance_outside(position) - tuning.outside_margin
	if outside <= 0.0:
		if gravity_on:
			velocity += Vector3.DOWN * tuning.gravity * delta
		return velocity
	var toward := (arena.closest_point_inside(position) - position).normalized()
	velocity += toward * (tuning.pull_back_accel + tuning.pull_back_per_meter * outside) * delta
	var outward_speed := -velocity.dot(toward)
	if outward_speed > 0.0:
		velocity += toward * outward_speed * minf(1.0, tuning.pull_back_damping * delta)
	return velocity


## Moves `body` with move_and_slide(), then bounces it off whatever it hit (see bounce()).
## Shared by the players and the ball.
static func move_and_bounce(body: CharacterBody3D, restitution: float, friction: float) -> void:
	var before := body.velocity
	body.move_and_slide()
	var count := body.get_slide_collision_count()
	if count == 0:
		return
	var v := before
	for i: int in count:
		var collision := body.get_slide_collision(i)
		v = bounce(v, collision.get_normal(), collision.get_collider_velocity(), restitution, friction)
	body.velocity = v


## Bounce off a surface moving at `surface_velocity`: reflect the into-surface part of the
## velocity scaled by `restitution`, and keep `1 - friction` of the sliding part.
static func bounce(velocity: Vector3, normal: Vector3, surface_velocity: Vector3,
		restitution: float, friction: float) -> Vector3:
	var relative := velocity - surface_velocity
	var into := relative.dot(normal)
	if into >= 0.0:
		return velocity
	var normal_part := normal * into
	var tangent_part := relative - normal_part
	relative = tangent_part * (1.0 - friction) - normal_part * restitution
	return relative + surface_velocity
