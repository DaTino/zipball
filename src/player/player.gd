class_name Player
extends CharacterBody3D
## One player's simulation: aim, grapple, air control, gravity and bounces off beams.
##
## Match calls simulate() once per tick with that tick's PlayerInput. Nothing here reads
## devices or runs on its own clock, so the same inputs always give the same result.
## Presentation (body facing, rope, camera) lives in PlayerVisuals and PlayerCamera.
##
## The grapple is modeled on the Q-Claw in 007: Agent Under Fire. Hold the button and the
## hook flies out. Once it lands on a zip point (a beam or an orb), the line pulls you in and
## you hang there. Let go any time to fly off with your speed. Letting the line out (E / R2)
## stops the pull and leaves a plain rope to swing on. If the hook lands on a loose ball
## instead, the line reels the ball in to you (see Ball).

## What the grapple is doing.
enum GrappleState {
	OFF, ## Not fired, missed, or let go.
	FLYING, ## The hook is on its way to a zip point or the ball.
	PULLING, ## The line pulls you toward the zip point, with no gravity.
	HANGING, ## Reached the zip point: held in place, moving with the cube.
	ROPE, ## A plain rope: holds its length, Q/E change it, gravity applies.
	REELING_BALL, ## The hook caught the ball, and the line reels it in to you.
}

## Lattice.Hit.index for a grapple shot at the ball.
const BALL_TARGET := -1
## The pull counts as arrived this close to hang_distance() (m).
const ARRIVE_TOLERANCE := 0.1
## How far E / R2 must be pressed to stop the pull, so a resting trigger doesn't.
const LET_OUT_THRESHOLD := 0.5

@export var tuning: MovementTuning
@export var team := 0

## Set by Match before the first tick.
var arena: Arena
## Set by Match before the first tick. Null when there's no ball to hook.
var ball: Ball
## Aim used by the simulation this tick (radians).
var yaw := 0.0
var pitch := 0.0
var grapple_state := GrappleState.OFF
## True once the hook has landed: pulling, hanging or on the rope.
var grapple_attached: bool:
	get:
		return grapple_state == GrappleState.PULLING or grapple_state == GrappleState.HANGING \
				or grapple_state == GrappleState.ROPE
## Attach point in arena-local space, so it turns with the arena. While the hook flies, it's
## where the hook is headed. Not used for the ball, which moves.
var grapple_anchor_local := Vector3.ZERO
## True while the hook is headed for, or holding, the ball rather than a zip point.
var grapple_on_ball := false
## How far the hook has flown (m), while it's flying.
var hook_travel := 0.0
var rope_length := 0.0
## Testing switch (Match sets it). When false, there's no downward gravity inside the cube;
## the pull back from outside still applies.
var gravity_enabled := true
## Reel mode (the menu's Grapple choice): once the hook lands, the line pulls you in. When
## false (Swing mode), it lands as a plain rope at its current length and you swing on it,
## like the first prototype. Match sets it.
var auto_reel := true

var _grapple_was_held := false
## Where you hang, in arena-local space (while hanging).
var _hang_local := Vector3.ZERO


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()


## Advances this player by one tick.
func simulate(input: PlayerInput, delta: float) -> void:
	yaw = input.yaw
	pitch = clampf(input.pitch, -Movement.PITCH_LIMIT, Movement.PITCH_LIMIT)
	_update_grapple_button(input.grapple_held, delta)
	if grapple_state == GrappleState.PULLING \
			and _distance_to_anchor() <= hang_distance() + ARRIVE_TOLERANCE:
		_start_hanging()
	if input.reel < -LET_OUT_THRESHOLD \
			and (grapple_state == GrappleState.PULLING or grapple_state == GrappleState.HANGING):
		_let_out()

	if grapple_state == GrappleState.HANGING:
		velocity = _hang_velocity(delta)
		_move_and_bounce()
		return

	var v := velocity
	if grapple_state != GrappleState.PULLING:
		v = Movement.apply_environment(v, global_position, arena, tuning, gravity_enabled, delta)

	var wish := _wish_direction(input.move)
	if wish != Vector3.ZERO:
		var accel := tuning.air_accel * minf(input.move.length(), 1.0)
		v = Movement.air_control(v, wish, accel, tuning.air_max_speed, delta)

	v *= maxf(0.0, 1.0 - tuning.drag * delta)
	if grapple_state == GrappleState.PULLING:
		v = _pull(v, delta)
	elif grapple_state == GrappleState.ROPE:
		rope_length = clampf(rope_length - input.reel * tuning.reel_speed * delta,
				tuning.min_rope_length, tuning.max_rope_length)
		var anchor := grapple_anchor_world()
		v = Movement.apply_rope(global_position, v, anchor, arena.velocity_at(anchor),
				rope_length, delta, tuning.max_rope_pull_speed)

	velocity = v.limit_length(tuning.max_speed)
	_move_and_bounce()


## Puts the player somewhere with no velocity and no grapple (spawns, respawns, tests).
func place(world_position: Vector3, p_yaw: float, p_pitch: float) -> void:
	global_position = world_position
	velocity = Vector3.ZERO
	yaw = p_yaw
	pitch = p_pitch
	grapple_state = GrappleState.OFF
	grapple_on_ball = false
	hook_travel = 0.0
	_grapple_was_held = false
	reset_physics_interpolation()


func aim_direction() -> Vector3:
	return -Movement.aim_basis(yaw, pitch).z


func grapple_anchor_world() -> Vector3:
	return arena.to_global(grapple_anchor_local)


## How far from the zip point's center (or a beam's center line) you hang.
func hang_distance() -> float:
	return arena.lattice.zip_radius + tuning.hang_gap


## Where a grapple fired from here along `direction` would land, or null. The ball wins
## whenever the line can reach it (directly or with aim assist), unless a zip point is
## directly in the way. A ball hit has index BALL_TARGET.
func find_grapple_target(direction: Vector3) -> Lattice.Hit:
	var assist := deg_to_rad(tuning.aim_assist_degrees)
	var zip_assist := assist
	if arena.zip_points == Lattice.ZipPoints.ORBS:
		zip_assist = deg_to_rad(tuning.orb_aim_assist_degrees)
	var hit := arena.raycast_zip_points(global_position, direction, tuning.grapple_range, zip_assist)
	var ball_hit := _find_ball(direction, assist)
	if ball_hit == null or (hit != null and not hit.assisted and hit.distance < ball_hit.distance):
		return hit
	return ball_hit


## A grapple shot at the ball, if it's loose and the line can reach it. The anchor is the
## near side of the ball, in arena-local space (for the crosshair marker).
func _find_ball(direction: Vector3, assist_angle: float) -> Lattice.Hit:
	if ball == null or not ball.can_be_hooked_by(self):
		return null
	var to_ball := ball.global_position - global_position
	var distance := to_ball.length()
	if distance <= ball.radius or distance - ball.radius > tuning.grapple_range:
		return null
	# Angle from the aim to the ball's near edge (negative when aimed right at it).
	var off := direction.angle_to(to_ball) - asin(ball.radius / distance)
	if off > assist_angle:
		return null
	var hit := Lattice.Hit.new()
	hit.index = BALL_TARGET
	hit.distance = distance - ball.radius
	hit.anchor = arena.to_local(ball.global_position - to_ball / distance * ball.radius)
	hit.assisted = off > 0.0
	return hit


func _update_grapple_button(held: bool, delta: float) -> void:
	if not held:
		grapple_state = GrappleState.OFF
	elif not _grapple_was_held:
		var hit := find_grapple_target(aim_direction())
		if hit != null:
			grapple_on_ball = hit.index == BALL_TARGET
			grapple_anchor_local = hit.anchor
			hook_travel = 0.0
			grapple_state = GrappleState.FLYING
	_grapple_was_held = held

	if grapple_on_ball and _lost_the_ball():
		grapple_state = GrappleState.OFF
	if grapple_state == GrappleState.FLYING:
		var distance := _hook_target_distance()
		if tuning.hook_speed > 0.0:
			hook_travel += tuning.hook_speed * delta
		else:
			hook_travel = distance
		if hook_travel >= distance:
			hook_travel = distance
			if grapple_on_ball:
				grapple_state = GrappleState.REELING_BALL
				ball.hook(self)
			else:
				rope_length = clampf(distance, tuning.min_rope_length, tuning.max_rope_length)
				grapple_state = GrappleState.PULLING if auto_reel and tuning.pull_speed > 0.0 else GrappleState.ROPE


## True when a line headed for (or holding) the ball has nothing left to do: someone
## (maybe you) has caught the ball, someone else's hook took it, or it went back to the center.
func _lost_the_ball() -> bool:
	if grapple_state == GrappleState.FLYING:
		return not ball.can_be_hooked_by(self)
	if grapple_state == GrappleState.REELING_BALL:
		return ball.reeled_by != self
	return false


## How far the flying hook has to go: to the zip point's anchor, or to the ball's near side.
func _hook_target_distance() -> float:
	if grapple_on_ball:
		return maxf(global_position.distance_to(ball.global_position) - ball.radius, 0.0)
	return _distance_to_anchor()


func _distance_to_anchor() -> float:
	return global_position.distance_to(grapple_anchor_world())


## The auto-reel. Speeds you up toward the zip point, removes some of your sideways speed, and
## brakes so you stop at hang_distance() instead of hitting it. Speeds are measured
## against the zip point, which moves with the cube.
func _pull(v: Vector3, delta: float) -> Vector3:
	var anchor := grapple_anchor_world()
	var anchor_velocity := arena.velocity_at(anchor)
	var to_anchor := anchor - global_position
	var distance := to_anchor.length() # More than hang_distance(), or we'd be hanging.
	var direction := to_anchor / distance
	var relative := v - anchor_velocity
	var inward := relative.dot(direction)
	var sideways := relative - direction * inward

	var accel := tuning.pull_accel * delta
	if inward < tuning.pull_speed: # Never slows down someone already going faster.
		inward = minf(inward + accel, tuning.pull_speed)
	var room := maxf(distance - hang_distance(), 0.0)
	inward = minf(inward, minf(sqrt(2.0 * tuning.pull_accel * room), room / delta))
	sideways = sideways.move_toward(Vector3.ZERO, accel * (1.0 - tuning.pull_keep_sideways))

	# The line never pays out while it pulls, so it also stops you drifting away.
	rope_length = clampf(minf(rope_length, distance), tuning.min_rope_length, tuning.max_rope_length)
	v = direction * inward + sideways + anchor_velocity
	return Movement.apply_rope(global_position, v, anchor, anchor_velocity, rope_length, delta,
			tuning.max_rope_pull_speed)


func _start_hanging() -> void:
	grapple_state = GrappleState.HANGING
	var from_anchor := arena.to_local(global_position) - grapple_anchor_local
	_hang_local = grapple_anchor_local + from_anchor.normalized() * hang_distance()
	rope_length = hang_distance()


## Velocity that keeps you on your hang point as the cube turns.
func _hang_velocity(delta: float) -> Vector3:
	var target := arena.to_global(_hang_local)
	return arena.velocity_at(target) + (target - global_position) / delta


## Stops the pull (or leaves the hang) and turns the line into a plain rope at its current length.
func _let_out() -> void:
	grapple_state = GrappleState.ROPE
	rope_length = clampf(_distance_to_anchor(), tuning.min_rope_length, tuning.max_rope_length)


func _wish_direction(move: Vector2) -> Vector3:
	if move == Vector2.ZERO:
		return Vector3.ZERO
	var forward := Movement.flat_forward(yaw)
	if tuning.air_control_follows_pitch:
		forward = aim_direction()
	var wish := forward * move.y + Movement.flat_right(yaw) * move.x
	return wish.normalized()


func _move_and_bounce() -> void:
	Movement.move_and_bounce(self, tuning.bounce, tuning.pipe_friction)
