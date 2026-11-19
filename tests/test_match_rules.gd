extends "res://tools/test_case.gd"
## Match rules: goals and the score (D13), the faceoff and its countdown (D14), and how a
## match ends (D15).

const MATCH_SCENE := preload("res://src/match/match.tscn")

var match_node: Match
var arena: Arena
var ball: Ball
var source: ScriptedInputSource
var player: Player
## Every goal_scored signal so far, as [team, own_goal].
var goals: Array[Array] = []
## Every match_ended signal so far (the winning team).
var endings: Array[int] = []


## A default match (timed, 5 minutes) with one scripted player on team 0. Starts in play
## unless `countdown`. No spin and no gravity, so placed things stay where they're put.
func _make_match(countdown := false, settings: MatchSettings = null) -> void:
	match_node = MATCH_SCENE.instantiate() as Match
	match_node.auto_add_local_player = false
	match_node.opening_countdown = countdown
	match_node.settings = settings
	add_to_tree(match_node)
	arena = match_node.arena
	ball = match_node.ball
	arena.spin_enabled = false
	match_node.set_gravity_enabled(false)
	match_node.goal_scored.connect(func(team: int, own_goal: bool) -> void: goals.append([team, own_goal]))
	match_node.match_ended.connect(func(team: int) -> void: endings.append(team))
	source = ScriptedInputSource.new()
	player = match_node.add_player(source, 0)


func _goal_world(team: int) -> Vector3:
	return arena.to_global(arena.goal_local_position(team))


## One cell out from `team`'s goal toward the cube's center, along Z: an open corridor
## leads straight from there into the goal.
func _near_goal(team: int) -> Vector3:
	var goal_local := arena.goal_local_position(team)
	return arena.to_global(goal_local - Vector3(0.0, 0.0, signf(goal_local.z) * arena.spacing))


## Puts the player one cell out from `team`'s goal, aimed at it, holding the ball.
func _hold_ball_near_goal(team: int) -> void:
	var start := _near_goal(team)
	var aim := Movement.aim_toward(_goal_world(team) - start)
	player.place(start, aim.x, aim.y)
	source.set_aim(aim.x, aim.y)
	ball.reset_to(start + player.aim_direction() * (ball.radius + 1.0))
	await wait_physics_ticks(1)
	assert_true(ball.carrier == player, "should be holding the ball")
	assert_eq(match_node.goal_touched(), -1, "a carried ball one cell out shouldn't touch the goal yet")


## Sends the ball, loose and touched by nobody, from one cell out straight into `team`'s goal.
func _launch_into_goal(team: int) -> void:
	var start := _near_goal(team)
	ball.reset_to(start)
	ball.frozen = false
	ball.velocity = (_goal_world(team) - start).normalized() * 80.0


func _scored() -> bool:
	return not goals.is_empty()


## Runs ticks until `condition` returns true. Returns how many it took, or -1 after `max_ticks`.
func _ticks_until(condition: Callable, max_ticks: int) -> int:
	for i: int in max_ticks + 1:
		if condition.call():
			return i
		await wait_physics_ticks(1)
	return -1


## Waits out the goal pause and the countdown that follows, until play starts again.
func _wait_for_play() -> void:
	var ticks: int = await _ticks_until(func() -> bool: return match_node.phase == Match.Phase.PLAYING, 600)
	assert_true(ticks >= 0, "play should start again")


func test_thrown_ball_in_their_goal_scores() -> void:
	_make_match()
	await _hold_ball_near_goal(1)
	source.next_input.throw_held = true
	await wait_physics_ticks(10)
	source.next_input.throw_held = false
	var ticks: int = await _ticks_until(_scored, 120)
	assert_true(ticks >= 0, "the throw should reach the goal")
	assert_eq(match_node.score, [1, 0] as Array[int])
	assert_eq(goals, [[0, false]] as Array[Array])
	assert_eq(match_node.phase, Match.Phase.GOAL)
	assert_true(ball.pinned, "the ball should stay where it scored")
	assert_true(ball.global_position.distance_to(_goal_world(1)) <= arena.goal_radius + ball.radius + 0.01,
			"it should be touching the goal")


func test_carried_ball_in_their_goal_scores() -> void:
	_make_match()
	await _hold_ball_near_goal(1)
	player.velocity = player.aim_direction() * 20.0
	var ticks: int = await _ticks_until(_scored, 120)
	assert_true(ticks >= 0, "carrying it in should score")
	assert_eq(match_node.score, [1, 0] as Array[int])
	assert_eq(goals, [[0, false]] as Array[Array])
	assert_true(ball.carrier == null, "the carrier loses the ball to the goal")
	assert_true(ball.last_touch == player)


func test_own_goal_counts_for_the_other_team() -> void:
	_make_match()
	await _hold_ball_near_goal(0)
	source.next_input.throw_held = true
	await wait_physics_ticks(1)
	source.next_input.throw_held = false
	var ticks: int = await _ticks_until(_scored, 120)
	assert_true(ticks >= 0, "the throw should reach the goal")
	assert_eq(match_node.score, [0, 1] as Array[int])
	assert_eq(goals, [[1, true]] as Array[Array], "a point for team 1, flagged as an own goal")
	assert_eq(match_node.last_goal_team, 1)
	assert_true(match_node.last_goal_own)


func test_goals_count_while_the_cube_turns() -> void:
	_make_match()
	arena.spin_enabled = true
	await wait_physics_ticks(120) # Turned well away from where it started.
	_launch_into_goal(0)
	var ticks: int = await _ticks_until(_scored, 120)
	assert_true(ticks >= 0, "the goal turns with the cube, and the ball should still find it")
	assert_eq(goals, [[1, false]] as Array[Array], "nobody touched it, so not an own goal")


func test_after_a_goal_and_a_pause_everyone_faces_off() -> void:
	_make_match()
	await _hold_ball_near_goal(1)
	player.velocity = player.aim_direction() * 20.0
	await _ticks_until(_scored, 120)
	var clock := match_node.time_left_ticks
	var in_goal := ball.global_position

	# The pause: the ball stays in the goal and can't be grabbed; nobody is held.
	var pause := match_node.seconds_to_ticks(match_node.goal_pause_seconds)
	assert_eq(pause, 2 * Engine.physics_ticks_per_second, "a 2 s pause by default")
	player.place(ball.global_position + Vector3.UP * (ball.radius + 1.0), 0.0, 0.0)
	await wait_physics_ticks(pause - 1)
	assert_eq(match_node.phase, Match.Phase.GOAL)
	assert_true(ball.carrier == null, "nobody can grab the ball during the pause")
	assert_almost_eq(ball.global_position, in_goal, 0.001)
	assert_false(player.held)

	await wait_physics_ticks(1)
	assert_eq(match_node.phase, Match.Phase.COUNTDOWN)
	assert_almost_eq(ball.global_position, match_node.faceoff_position(), 0.001)
	assert_true(ball.frozen and not ball.pinned, "frozen at the center, back in play")
	var spawn := arena.to_global(arena.spawn_local_position(0))
	assert_almost_eq(player.global_position, spawn, 0.001)
	assert_almost_eq(player.velocity, Vector3.ZERO, 0.001)
	assert_almost_eq(player.aim_direction(), (match_node.faceoff_position() - spawn).normalized(), 0.001,
			"facing the ball")
	assert_almost_eq(source.get_live_aim(), Vector2(player.yaw, player.pitch), 0.001,
			"the input source aims that way too")
	assert_true(player.held)
	assert_eq(match_node.time_left_ticks, clock, "the clock stops between a goal and play")


func test_countdown_holds_players_for_three_seconds() -> void:
	_make_match(true)
	match_node.set_gravity_enabled(true) # So a released player starts falling at once.
	var countdown := match_node.seconds_to_ticks(match_node.countdown_seconds)
	assert_eq(countdown, 3 * Engine.physics_ticks_per_second)
	assert_eq(match_node.phase, Match.Phase.COUNTDOWN, "the match starts with a countdown")
	var spawn := player.global_position
	source.next_input.move = Vector2(0.0, 1.0)
	source.next_input.grapple_held = true # Aimed at the ball, which is in range.
	for i: int in countdown:
		await wait_physics_ticks(1)
		if player.global_position.distance_to(spawn) > 0.001 or player.grapple_state != Player.GrappleState.OFF:
			fail("moved or grappled on tick %d of %d" % [i + 1, countdown])
			return
		if ball.carrier != null or not ball.frozen:
			fail("the ball moved on tick %d" % (i + 1))
			return
	assert_eq(match_node.phase, Match.Phase.PLAYING)
	assert_false(player.held)
	assert_eq(match_node.time_left_ticks, 5 * 60 * Engine.physics_ticks_per_second,
			"the clock starts with play")
	await wait_physics_ticks(1)
	assert_true(player.global_position.distance_to(spawn) > 0.001, "should move once play starts")
	assert_eq(player.grapple_state, Player.GrappleState.FLYING, "a grapple held through the countdown fires on GO")


func test_aim_still_works_during_the_countdown() -> void:
	_make_match(true)
	source.set_aim(1.0, 0.3)
	await wait_physics_ticks(1)
	assert_almost_eq(player.yaw, 1.0, 0.0001)
	assert_almost_eq(player.pitch, 0.3, 0.0001)


func test_held_players_turn_with_the_cube() -> void:
	_make_match(true)
	arena.spin_enabled = true
	await wait_physics_ticks(90)
	assert_eq(match_node.phase, Match.Phase.COUNTDOWN)
	var spawn := arena.to_global(arena.spawn_local_position(0))
	assert_true(spawn.distance_to(arena.spawn_local_position(0)) > 0.5, "the cube should have turned")
	assert_almost_eq(player.global_position, spawn, 0.2, "held at the spawn as it turns")


func test_timed_match_ends_when_the_clock_runs_out() -> void:
	_make_match()
	assert_eq(match_node.time_left_ticks, 5 * 60 * Engine.physics_ticks_per_second, "5 minutes by default")
	match_node.score[0] = 1
	match_node.time_left_ticks = 10
	await wait_physics_ticks(9)
	assert_eq(match_node.phase, Match.Phase.PLAYING)
	await wait_physics_ticks(1)
	assert_eq(match_node.phase, Match.Phase.OVER)
	assert_eq(match_node.winner, 0)
	assert_eq(endings, [0] as Array[int])
	assert_true(ball.pinned, "the ball stops where it was")

	_launch_into_goal(1)
	await wait_physics_ticks(60)
	assert_eq(match_node.score, [1, 0] as Array[int], "nothing scores once the match is over")
	assert_eq(match_node.phase, Match.Phase.OVER)
	assert_false(player.held, "players can still fly and look around")


func test_a_ball_in_flight_at_zero_does_not_count() -> void:
	_make_match()
	match_node.score[1] = 1
	match_node.time_left_ticks = 1
	_launch_into_goal(1)
	await wait_physics_ticks(1)
	assert_eq(match_node.phase, Match.Phase.OVER, "the match ends the instant time is up")
	await wait_physics_ticks(60)
	assert_eq(match_node.score, [0, 1] as Array[int])
	assert_eq(match_node.winner, 1)


func test_tie_at_full_time_goes_to_overtime_and_the_next_goal_wins() -> void:
	_make_match()
	match_node.countdown_seconds = 0.1
	match_node.time_left_ticks = 5
	await wait_physics_ticks(5)
	assert_true(match_node.overtime, "a tie goes to overtime")
	assert_eq(match_node.phase, Match.Phase.COUNTDOWN, "overtime starts with a faceoff")
	assert_true(endings.is_empty())

	await _wait_for_play()
	await wait_physics_ticks(30)
	assert_eq(match_node.phase, Match.Phase.PLAYING, "no clock ends overtime")
	assert_eq(match_node.overtime_ticks, 30, "the overtime clock counts up during play")

	_launch_into_goal(1)
	var ticks: int = await _ticks_until(_scored, 120)
	assert_true(ticks >= 0, "the ball should reach the goal")
	assert_eq(match_node.phase, Match.Phase.OVER, "the next goal ends it, with no faceoff after")
	assert_eq(match_node.winner, 0)
	assert_eq(endings, [0] as Array[int])


func test_points_match_ends_when_a_team_reaches_the_target() -> void:
	var settings := MatchSettings.new()
	settings.match_rule = MatchSettings.MatchRule.POINTS
	settings.points_to_win = 2
	_make_match(false, settings)
	match_node.countdown_seconds = 0.1
	match_node.goal_pause_seconds = 0.1
	match_node.time_left_ticks = 1
	await wait_physics_ticks(5)
	assert_eq(match_node.phase, Match.Phase.PLAYING, "a points match has no time limit")

	_launch_into_goal(1)
	await _ticks_until(_scored, 120)
	assert_eq(match_node.score, [1, 0] as Array[int])
	assert_eq(match_node.phase, Match.Phase.GOAL, "one short of the target: play goes on")

	await _wait_for_play()
	goals.clear()
	_launch_into_goal(1)
	await _ticks_until(_scored, 120)
	assert_eq(match_node.score, [2, 0] as Array[int])
	assert_eq(match_node.phase, Match.Phase.OVER)
	assert_eq(match_node.winner, 0)
