extends "res://tools/test_case.gd"
## Pure movement math: rope, air control, bounce, aim.

const DT := 1.0 / 60.0


func test_taut_rope_removes_outward_velocity() -> void:
	# At the rope's full length, moving straight away from the anchor.
	var v := Movement.apply_rope(Vector3(5, 0, 0), Vector3(3, 2, 0), Vector3.ZERO, Vector3.ZERO, 5.0, DT, 25.0)
	assert_almost_eq(v, Vector3(0, 2, 0), 0.0001)


func test_slack_rope_does_nothing() -> void:
	var v := Movement.apply_rope(Vector3(2, 0, 0), Vector3(3, 2, 0), Vector3.ZERO, Vector3.ZERO, 5.0, DT, 25.0)
	assert_almost_eq(v, Vector3(3, 2, 0))


func test_pendulum_keeps_length_and_energy() -> void:
	# Start level with the anchor, rope taut, at rest. Swing for 10 seconds.
	var length := 5.0
	var p := Vector3(length, 0, 0)
	var v := Vector3.ZERO
	var max_distance := 0.0
	var max_speed := 0.0
	for i: int in 600:
		v += Vector3.DOWN * 9.8 * DT
		v = Movement.apply_rope(p, v, Vector3.ZERO, Vector3.ZERO, length, DT, 25.0)
		p += v * DT
		max_distance = maxf(max_distance, p.length())
		max_speed = maxf(max_speed, v.length())
	assert_true(max_distance < length + 0.05, "rope stretched to %.3f m" % max_distance)
	var ideal := sqrt(2.0 * 9.8 * length) # Speed at the bottom with no losses.
	assert_almost_eq(max_speed, ideal, ideal * 0.1, "speed at the bottom of the swing")


func test_shortening_rope_pulls_player_in() -> void:
	var v := Movement.apply_rope(Vector3(5, 0, 0), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 4.8, DT, 25.0)
	assert_true(v.x < 0.0, "should be pulled toward the anchor")
	assert_true(v.length() <= 25.0 + 0.001, "pull is capped")


func test_air_control_caps_at_max_speed() -> void:
	var v := Vector3.ZERO
	for i: int in 600:
		v = Movement.air_control(v, Vector3.FORWARD, 8.0, 10.0, DT)
	assert_almost_eq(v.length(), 10.0, 0.001)


func test_air_control_never_slows_fast_momentum() -> void:
	var v := Movement.air_control(Vector3(0, 0, -30), Vector3.FORWARD, 8.0, 10.0, DT)
	assert_almost_eq(v, Vector3(0, 0, -30))


func test_bounce_reflects_with_restitution() -> void:
	var v := Movement.bounce(Vector3(2, -10, 0), Vector3.UP, Vector3.ZERO, 0.3, 0.1)
	assert_almost_eq(v, Vector3(1.8, 3.0, 0), 0.0001)


func test_bounce_ignores_surfaces_moving_away() -> void:
	var v := Movement.bounce(Vector3(0, 5, 0), Vector3.UP, Vector3.ZERO, 0.3, 0.1)
	assert_almost_eq(v, Vector3(0, 5, 0))


func test_aim_toward_round_trips() -> void:
	for direction: Vector3 in [Vector3(1, 1, 1), Vector3(-2, 0.5, 3), Vector3(0, -1, -4)]:
		var aim := Movement.aim_toward(direction)
		var forward := -Movement.aim_basis(aim.x, aim.y).z
		assert_almost_eq(forward, direction.normalized(), 0.0001)
