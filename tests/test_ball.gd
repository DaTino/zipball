extends "res://tools/test_case.gd"
## Ball possession: grabbing a loose ball when close, carrying it, and respawning with it.

const MATCH_SCENE := preload("res://src/match/match.tscn")

var match_node: Match
var ball: Ball
var source: ScriptedInputSource
var player: Player


func before_each() -> void:
	match_node = MATCH_SCENE.instantiate() as Match
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	match_node.arena.spin_enabled = false
	match_node.set_gravity_enabled(false) # So placed players stay where they're put.
	ball = match_node.ball
	source = ScriptedInputSource.new()
	player = match_node.add_player(source, 0)
	source.set_aim(0.0, 0.0) # Look along -Z, down an open corridor through the center cell.


## Puts `who` this far (m) from the ball's surface, on the side given by `side`.
func _place_near_ball(who: Player, gap: float, side := Vector3.RIGHT) -> void:
	who.place(ball.global_position + side * (ball.radius + gap), 0.0, 0.0)


func test_ball_starts_loose_at_the_center() -> void:
	assert_null_carrier()
	assert_almost_eq(ball.global_position, match_node.faceoff_position(), 0.001)


func test_ball_is_three_meters_across() -> void:
	assert_almost_eq(ball.radius, 1.5, 0.001)
	var mesh := (ball.get_node(^"Mesh") as MeshInstance3D).mesh as SphereMesh
	assert_almost_eq(mesh.radius, ball.radius, 0.001, "the mesh should match the radius")
	var shape := (ball.get_node(^"CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	assert_almost_eq(shape.radius, ball.radius, 0.001, "the collision shape should match the radius")


func test_ball_waits_at_the_faceoff_spot_until_first_touch() -> void:
	match_node.set_gravity_enabled(true)
	await wait_physics_ticks(30)
	assert_true(ball.frozen, "should still be frozen")
	assert_almost_eq(ball.global_position, match_node.faceoff_position(), 0.001)


func test_player_within_pickup_distance_grabs_the_ball() -> void:
	_place_near_ball(player, ball.pickup_distance - 0.1)
	await wait_physics_ticks(1)
	assert_true(ball.carrier == player, "should have the ball")


func test_player_just_out_of_range_does_not() -> void:
	_place_near_ball(player, ball.pickup_distance + 0.3)
	await wait_physics_ticks(5)
	assert_null_carrier()


func test_carried_ball_rides_in_front_of_the_carrier() -> void:
	_place_near_ball(player, 1.0)
	await wait_physics_ticks(1)
	player.place(match_node.arena.to_global(match_node.arena.spawn_local_position(0)), 0.5, 0.2)
	source.set_aim(0.5, 0.2)
	await wait_physics_ticks(1)
	assert_almost_eq(ball.global_position, ball.carry_position(player), 0.001)
	assert_almost_eq(ball.global_position.distance_to(player.global_position),
			ball.radius + Ball.CARRY_GAP, 0.001)


func test_first_player_in_order_gets_the_ball() -> void:
	var other := match_node.add_player(ScriptedInputSource.new(), 1)
	_place_near_ball(other, 0.5, Vector3.LEFT)
	_place_near_ball(player, 0.5, Vector3.RIGHT)
	await wait_physics_ticks(1)
	assert_true(ball.carrier == player, "player 0 is simulated first, so they should get it")


func test_respawning_returns_the_ball_to_the_center() -> void:
	_place_near_ball(player, 1.0)
	await wait_physics_ticks(1)
	source.next_input.respawn = true
	await wait_physics_ticks(1)
	assert_null_carrier()
	assert_almost_eq(ball.global_position, match_node.faceoff_position(), 0.001)


## Grabs the ball, holds the throw button for `hold_ticks`, then lets go (one more tick).
func _grab_and_throw(hold_ticks: int) -> void:
	_place_near_ball(player, 1.0)
	await wait_physics_ticks(1)
	assert_true(ball.carrier == player, "should have the ball before throwing")
	source.next_input.throw_held = true
	await wait_physics_ticks(hold_ticks)
	source.next_input.throw_held = false
	await wait_physics_ticks(1)


## Lets the ball go at `position` with `velocity`, as if it had been thrown.
func _launch_ball(position: Vector3, velocity: Vector3) -> void:
	ball.reset_to(position)
	ball.frozen = false
	ball.velocity = velocity


func test_quick_throw_goes_at_minimum_speed() -> void:
	await _grab_and_throw(1)
	assert_null_carrier()
	var expected := ball.throw_speed(1.0 / Engine.physics_ticks_per_second / ball.charge_time)
	assert_almost_eq(ball.velocity, player.aim_direction() * expected, 0.05)
	assert_true(expected < ball.throw_min_speed + 2.0, "a tap should be near the minimum, got %.1f" % expected)


func test_full_charge_throws_at_maximum_speed() -> void:
	var ticks := ceili(ball.charge_time * Engine.physics_ticks_per_second) + 10
	await _grab_and_throw(ticks)
	assert_almost_eq(ball.velocity.length(), ball.throw_max_speed, 0.05)


func test_charge_shows_while_holding_the_button() -> void:
	_place_near_ball(player, 1.0)
	await wait_physics_ticks(1)
	source.next_input.throw_held = true
	await wait_physics_ticks(30)
	assert_true(ball.carrier == player, "holding the button shouldn't throw yet")
	assert_almost_eq(ball.charge_fraction(), 30.0 / Engine.physics_ticks_per_second / ball.charge_time, 0.02)


## The thrower's own velocity isn't added (D12): the ball flies straight down the crosshair
## line at the charge's speed, even when the thrower is moving fast across it.
func test_throw_flies_straight_along_the_aim_whatever_the_thrower_is_doing() -> void:
	_place_near_ball(player, 1.0)
	await wait_physics_ticks(1)
	source.next_input.throw_held = true
	await wait_physics_ticks(5)
	player.velocity = Vector3(30.0, 10.0, 20.0) # Sideways, up and backward.
	source.next_input.throw_held = false
	await wait_physics_ticks(1)
	assert_null_carrier()
	var aim := player.aim_direction()
	var speed := ball.throw_speed(5.0 / Engine.physics_ticks_per_second / ball.charge_time)
	assert_almost_eq(ball.velocity, aim * speed, 0.05, "speed from the charge alone, along the aim")

	var start := ball.global_position
	await wait_physics_ticks(20)
	var travelled := ball.global_position - start
	var off_line := travelled - aim * travelled.dot(aim)
	assert_true(travelled.dot(aim) > speed * 0.3, "it should have flown forward, %s" % travelled)
	assert_true(off_line.length() < 0.05, "and stayed on the aim line, %.2f m off" % off_line.length())


func test_thrower_must_wait_to_grab_it_again() -> void:
	await _grab_and_throw(1)
	var wait_ticks := floori(ball.regrab_delay * Engine.physics_ticks_per_second) - 3
	for i: int in wait_ticks:
		_place_near_ball(player, 0.5)
		await wait_physics_ticks(1)
		if ball.carrier != null:
			fail("grabbed it back after %d ticks" % (i + 1))
			return
	await wait_physics_ticks(5)
	_place_near_ball(player, 0.5)
	await wait_physics_ticks(1)
	assert_true(ball.carrier == player, "should be able to grab it after the delay")


func test_someone_else_can_catch_a_throw_right_away() -> void:
	var other := match_node.add_player(ScriptedInputSource.new(), 1)
	await _grab_and_throw(1)
	_place_near_ball(other, 0.5)
	await wait_physics_ticks(1)
	assert_true(ball.carrier == other, "the other player should catch it")


func test_thrown_ball_falls_under_gravity() -> void:
	match_node.set_gravity_enabled(true)
	_launch_ball(match_node.faceoff_position(), Vector3(0.0, 0.0, -15.0))
	await wait_physics_ticks(30)
	assert_true(ball.velocity.y < -4.4, "after ~0.5 s expected about -4.9 m/s, got %.2f" % ball.velocity.y)
	assert_true(ball.velocity.z < -14.0, "should keep flying forward, %s" % ball.velocity)


func test_ball_bounces_off_a_pipe() -> void:
	var spacing := match_node.arena.spacing
	# A Z pipe runs through (half a cell, half a cell) from the center. Fly straight up at it.
	var pipe := Vector3(spacing * 0.5, spacing * 0.5, 0.0)
	_launch_ball(Vector3(pipe.x, pipe.y - 6.0, 0.0), Vector3(0.0, 10.0, 0.0))
	await wait_physics_ticks(60)
	var contact_y := pipe.y - ball.radius - match_node.arena.zip_radius
	assert_true(ball.global_position.y < contact_y + 0.05, "should never pass through, at y %.2f" % ball.global_position.y)
	assert_true(ball.velocity.y < -4.0, "should bounce back down, got %.2f" % ball.velocity.y)


func test_ball_is_pulled_back_into_the_cube() -> void:
	_launch_ball(Vector3(0.0, 0.0, match_node.arena.lattice.half_extent + 13.0), Vector3.ZERO)
	var before := match_node.arena.distance_outside(ball.global_position)
	await wait_physics_ticks(30)
	assert_true(match_node.arena.distance_outside(ball.global_position) < before - 2.0, "should head back")
	assert_true(ball.velocity.z < 0.0, "should be moving toward the cube")


func test_respawn_refreezes_a_thrown_ball_at_the_center() -> void:
	await _grab_and_throw(1)
	for i: int in 60: # Chase it until the regrab delay is over and they catch it.
		_place_near_ball(player, 0.5)
		await wait_physics_ticks(1)
		if ball.carrier == player:
			break
	assert_true(ball.carrier == player, "should have it again")
	source.next_input.respawn = true
	await wait_physics_ticks(1)
	assert_true(ball.frozen, "should be frozen at the faceoff spot")
	assert_almost_eq(ball.global_position, match_node.faceoff_position(), 0.001)


## Puts `who` this far (m) from the ball's center along +Z (down an open corridor) and aims
## them back along -Z, straight at it.
func _line_up_on_ball(who: Player, who_source: ScriptedInputSource, distance: float) -> void:
	who.place(ball.global_position + Vector3(0.0, 0.0, distance), 0.0, 0.0)
	who_source.set_aim(0.0, 0.0)


## Runs ticks until `condition` returns true. Returns how many it took, or -1 after `max_ticks`.
func _ticks_until(condition: Callable, max_ticks: int) -> int:
	for i: int in max_ticks + 1:
		if condition.call():
			return i
		await wait_physics_ticks(1)
	return -1


func _is_reeling(who: Player) -> bool:
	return who.grapple_state == Player.GrappleState.REELING_BALL


func test_hooking_the_ball_reels_it_in_until_you_catch_it() -> void:
	assert_true(ball.frozen, "starts frozen at the faceoff spot")
	_line_up_on_ball(player, source, 30.0)
	source.next_input.grapple_held = true
	var hooked: int = await _ticks_until(_is_reeling.bind(player), 30)
	assert_true(hooked >= 0, "the hook should reach the ball")
	assert_false(ball.frozen, "hooking it wakes it up")
	assert_true(ball.reeled_by == player)
	await wait_physics_ticks(10)
	assert_true(ball.velocity.z > 10.0, "should be flying toward the player, %s" % ball.velocity)
	var caught: int = await _ticks_until(func() -> bool: return ball.carrier == player, 120)
	assert_true(caught >= 0, "should reach the player and be caught")
	await wait_physics_ticks(1)
	assert_eq(player.grapple_state, Player.GrappleState.OFF, "the line lets go once you have it")


func test_letting_go_leaves_the_ball_flying_on() -> void:
	_line_up_on_ball(player, source, 30.0)
	source.next_input.grapple_held = true
	await _ticks_until(_is_reeling.bind(player), 30)
	await wait_physics_ticks(15)
	source.next_input.grapple_held = false
	await wait_physics_ticks(1)
	assert_null(ball.reeled_by)
	var speed := ball.velocity.z
	assert_true(speed > 5.0, "should be moving toward where the player is, %.1f" % speed)
	await wait_physics_ticks(5)
	assert_null_carrier()
	assert_almost_eq(ball.velocity.z, speed, 0.5, "no longer reeled, so it just flies on")


func test_aim_assist_catches_the_ball_on_a_near_miss() -> void:
	_line_up_on_ball(player, source, 30.0)
	# The ball's edge is asin(1.5 / 30) = 2.9 degrees off its center; aim 4 degrees off.
	var hit := player.find_grapple_target(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(4.0)))
	assert_true(hit != null and hit.index == Player.BALL_TARGET, "should catch the ball")
	if hit != null:
		assert_true(hit.assisted)


func test_a_beam_in_the_way_takes_the_hook_instead() -> void:
	var half_cell := match_node.arena.spacing * 0.5
	# A vertical beam runs through (half, 0, half). Put the ball behind it and aim through it.
	ball.reset_to(Vector3(half_cell, 0.0, 0.0))
	player.place(Vector3(half_cell, 0.0, half_cell * 2.5), 0.0, 0.0)
	var hit := player.find_grapple_target(Vector3.FORWARD)
	assert_true(hit != null and hit.index != Player.BALL_TARGET, "the beam should take it")


func test_thrower_cannot_hook_their_own_throw_right_away() -> void:
	await _grab_and_throw(1)
	var hit := player.find_grapple_target(ball.global_position - player.global_position)
	assert_true(hit == null or hit.index != Player.BALL_TARGET, "too soon after the throw")
	await wait_physics_ticks(ceili(ball.regrab_delay * Engine.physics_ticks_per_second) + 1)
	hit = player.find_grapple_target(ball.global_position - player.global_position)
	assert_true(hit != null and hit.index == Player.BALL_TARGET, "should be able to hook it now")


func test_a_newer_hook_takes_the_ball_away() -> void:
	var other_source := ScriptedInputSource.new()
	var other := match_node.add_player(other_source, 1)
	_line_up_on_ball(player, source, 30.0)
	other.place(ball.global_position + Vector3(0.0, 0.0, -30.0), PI, 0.0)
	other_source.set_aim(PI, 0.0) # Looking along +Z, at the ball from the other side.
	source.next_input.grapple_held = true
	await _ticks_until(_is_reeling.bind(player), 30)
	other_source.next_input.grapple_held = true
	var stolen: int = await _ticks_until(_is_reeling.bind(other), 30)
	assert_true(stolen >= 0, "the second hook should land")
	assert_true(ball.reeled_by == other)
	await wait_physics_ticks(1)
	assert_eq(player.grapple_state, Player.GrappleState.OFF, "the first line should drop")


func assert_null_carrier() -> void:
	assert_true(ball.carrier == null, "the ball should be loose")
