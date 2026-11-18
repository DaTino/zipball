extends "res://tools/test_case.gd"
## Player simulation inside a real match and arena, driven by scripted input.

const MATCH_SCENE := preload("res://src/match/match.tscn")

var match_node: Match
var source: ScriptedInputSource
var player: Player
## Team 0's spawn point (the arena doesn't spin in these tests, so local = world).
var spawn: Vector3
## A point on the Z pipe that runs past the spawn cell, half a cell over in X and Y.
var near_pipe: Vector3


func before_each() -> void:
	match_node = MATCH_SCENE.instantiate() as Match
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	match_node.arena.spin_enabled = false
	spawn = match_node.arena.spawn_local_position(0)
	var half_cell := match_node.arena.spacing * 0.5
	near_pipe = spawn + Vector3(half_cell, half_cell, 0)
	source = ScriptedInputSource.new()
	player = match_node.add_player(source, 0)


func _aim_at(world_point: Vector3) -> void:
	var aim := Movement.aim_toward(world_point - player.global_position)
	source.set_aim(aim.x, aim.y)


## Fires at the near pipe and waits for the hook to land.
func _attach_to_near_pipe() -> void:
	_aim_at(near_pipe)
	source.next_input.grapple_held = true
	var ticks: int = await _ticks_until(func() -> bool: return player.grapple_attached, 30)
	assert_true(ticks >= 0, "the hook should land")


## Runs ticks until `condition` returns true. Returns how many it took, or -1 after `max_ticks`.
func _ticks_until(condition: Callable, max_ticks: int) -> int:
	for i: int in max_ticks + 1:
		if condition.call():
			return i
		await wait_physics_ticks(1)
	return -1


## Gives this test its own copy of the tuning (the .tres is shared) with some values changed.
func _tune(values: Dictionary[String, float]) -> void:
	player.tuning = player.tuning.duplicate() as MovementTuning
	for key: String in values:
		player.tuning.set(key, values[key])


func _is_hanging() -> bool:
	return player.grapple_state == Player.GrappleState.HANGING


## Velocity split into speed toward the anchor and the sideways part (arena not spinning).
func _toward_anchor_speed() -> float:
	return player.velocity.dot((player.grapple_anchor_world() - player.global_position).normalized())


func _sideways_speed() -> float:
	var direction := (player.grapple_anchor_world() - player.global_position).normalized()
	return (player.velocity - direction * player.velocity.dot(direction)).length()


func test_spawns_in_open_space_facing_center() -> void:
	assert_almost_eq(player.global_position, spawn, 0.001)
	assert_true(match_node.arena.lattice.distance_to_nearest_zip_point(spawn) > 1.0, "spawn should be clear of pipes")
	assert_almost_eq(player.aim_direction(), Vector3.ONE.normalized(), 0.001)


func test_falls_under_gravity() -> void:
	await wait_physics_ticks(30)
	assert_true(player.velocity.y < -4.4, "after ~0.5 s expected about -4.9 m/s, got %.2f" % player.velocity.y)
	assert_almost_eq(player.velocity.x, 0.0, 0.001)


func test_grapple_attaches_where_aimed() -> void:
	await _attach_to_near_pipe()
	assert_true(player.grapple_attached, "grapple should attach")
	assert_almost_eq(player.grapple_anchor_local, near_pipe, 0.01)


func test_missed_shot_does_not_attach() -> void:
	source.set_aim(0.0, 0.0) # Looking along -Z down an open corridor from the spawn cell.
	source.next_input.grapple_held = true
	await wait_physics_ticks(1)
	assert_false(player.grapple_attached)


func test_rope_holds_length_while_swinging() -> void:
	_tune({"pull_speed": 0.0}) # Plain rope, no auto-reel.
	await _attach_to_near_pipe()
	assert_eq(player.grapple_state, Player.GrappleState.ROPE)
	var length := player.rope_length
	var farthest := 0.0
	for i: int in 90:
		await wait_physics_ticks(1)
		farthest = maxf(farthest, player.global_position.distance_to(player.grapple_anchor_world()))
	assert_true(farthest <= length + 0.15, "rope stretched from %.2f to %.2f m" % [length, farthest])
	assert_true(player.velocity.length() > 1.0, "should be swinging")


func test_reel_in_shortens_line_to_minimum() -> void:
	_tune({"pull_speed": 0.0})
	await _attach_to_near_pipe()
	source.next_input.reel = 1.0
	var seconds := (player.rope_length - player.tuning.min_rope_length) / player.tuning.reel_speed
	await wait_physics_ticks(ceili(seconds * Engine.physics_ticks_per_second) + 30)
	assert_almost_eq(player.rope_length, player.tuning.min_rope_length, 0.001)
	var distance := player.global_position.distance_to(player.grapple_anchor_world())
	assert_true(distance < player.tuning.min_rope_length + 0.3, "should be pulled in, at %.2f m" % distance)


func test_lengthen_line() -> void:
	_tune({"pull_speed": 0.0})
	await _attach_to_near_pipe()
	var before := player.rope_length
	source.next_input.reel = -1.0
	await wait_physics_ticks(30)
	assert_true(player.rope_length > before + 3.0, "line should grow, %.2f -> %.2f" % [before, player.rope_length])


func test_release_detaches() -> void:
	await _attach_to_near_pipe()
	await wait_physics_ticks(30)
	source.next_input.grapple_held = false
	await wait_physics_ticks(1)
	assert_false(player.grapple_attached)


func test_pulled_back_from_outside() -> void:
	player.place(Vector3(0, 0, match_node.arena.lattice.half_extent + 13.0), 0.0, 0.0)
	var before := match_node.arena.distance_outside(player.global_position)
	await wait_physics_ticks(30)
	var after := match_node.arena.distance_outside(player.global_position)
	assert_true(after < before - 2.0, "outside distance %.2f -> %.2f" % [before, after])
	assert_true(player.velocity.z < 0.0, "should be heading back toward the cube")


func test_spinning_arena_carries_the_anchor() -> void:
	match_node.arena.spin_enabled = true
	await _attach_to_near_pipe()
	var start := player.grapple_anchor_world()
	await wait_physics_ticks(60)
	assert_true(player.grapple_attached)
	assert_almost_eq(player.grapple_anchor_local, near_pipe, 0.01)
	assert_true(start.distance_to(player.grapple_anchor_world()) > 0.05, "anchor should move with the arena")


func test_hook_takes_time_to_fly_out() -> void:
	_aim_at(near_pipe)
	source.next_input.grapple_held = true
	await wait_physics_ticks(1)
	assert_eq(player.grapple_state, Player.GrappleState.FLYING)
	assert_false(player.grapple_attached, "the hook shouldn't land on the first tick")
	var per_tick := player.tuning.hook_speed / Engine.physics_ticks_per_second
	var expected := ceili(spawn.distance_to(near_pipe) / per_tick)
	var ticks: int = await _ticks_until(func() -> bool: return player.grapple_attached, 60)
	assert_true(absi(ticks + 1 - expected) <= 1, "landed after %d ticks, expected about %d" % [ticks + 1, expected])
	assert_almost_eq(player.grapple_anchor_local, near_pipe, 0.01)


func test_letting_go_before_the_hook_lands_cancels_it() -> void:
	_aim_at(near_pipe)
	source.next_input.grapple_held = true
	await wait_physics_ticks(1)
	source.next_input.grapple_held = false
	await wait_physics_ticks(20)
	assert_eq(player.grapple_state, Player.GrappleState.OFF)


func test_pull_speeds_you_straight_toward_the_pipe() -> void:
	await _attach_to_near_pipe()
	assert_eq(player.grapple_state, Player.GrappleState.PULLING)
	var seconds := player.tuning.pull_speed / player.tuning.pull_accel
	await wait_physics_ticks(ceili(seconds * Engine.physics_ticks_per_second) + 2)
	assert_almost_eq(_toward_anchor_speed(), player.tuning.pull_speed, 0.5, "speed toward the pipe")
	assert_true(_sideways_speed() < 0.2, "gravity shouldn't bend the pull, sideways %.2f" % _sideways_speed())


func test_pull_stops_and_hangs_at_the_pipe() -> void:
	await _attach_to_near_pipe()
	var ticks: int = await _ticks_until(_is_hanging, 180)
	assert_true(ticks >= 0, "should reach the pipe and hang")
	assert_almost_eq(player.global_position.distance_to(player.grapple_anchor_world()),
			player.hang_distance(), 0.15, "hang distance")
	await wait_physics_ticks(2) # Settle onto the exact hang point.
	var hang_point := player.global_position
	await wait_physics_ticks(60)
	assert_true(_is_hanging(), "should keep hanging while held")
	assert_almost_eq(player.global_position, hang_point, 0.02, "should stay put with gravity on")


func test_hanging_moves_with_the_spinning_arena() -> void:
	match_node.arena.spin_enabled = true
	await _attach_to_near_pipe()
	var ticks: int = await _ticks_until(_is_hanging, 180)
	assert_true(ticks >= 0, "should reach the pipe and hang")
	await wait_physics_ticks(2) # Settle onto the exact hang point.
	var arena := match_node.arena
	var local_point := arena.to_local(player.global_position)
	var world_point := player.global_position
	await wait_physics_ticks(120)
	assert_almost_eq(arena.to_local(player.global_position), local_point, 0.05, "should stay on its hang point")
	assert_true(player.global_position.distance_to(world_point) > 0.05, "should be carried by the arena")


func test_letting_go_mid_pull_keeps_your_speed() -> void:
	await _attach_to_near_pipe()
	await wait_physics_ticks(15)
	var before := player.velocity
	assert_true(before.length() > 20.0, "should be pulled fast, at %.1f m/s" % before.length())
	source.next_input.grapple_held = false
	await wait_physics_ticks(1)
	assert_eq(player.grapple_state, Player.GrappleState.OFF)
	assert_almost_eq(player.velocity, before, 0.5, "flung with the pull's speed")


func test_pull_can_keep_or_remove_sideways_speed() -> void:
	for keep: float in [0.0, 1.0]:
		player.place(spawn, 0.0, 0.0)
		_tune({"hook_speed": 0.0, "pull_keep_sideways": keep})
		source.next_input.grapple_held = false
		await wait_physics_ticks(1)
		player.velocity = Vector3(0.0, 0.0, 10.0) # Along the pipe, square to the line.
		await _attach_to_near_pipe()
		await wait_physics_ticks(10)
		if keep == 0.0:
			assert_true(_sideways_speed() < 0.5, "keep 0: sideways %.2f, expected about 0" % _sideways_speed())
		else:
			assert_true(_sideways_speed() > 9.0, "keep 1: sideways %.2f, expected about 10" % _sideways_speed())


func test_letting_the_line_out_stops_the_pull() -> void:
	await _attach_to_near_pipe()
	await wait_physics_ticks(10)
	source.next_input.reel = -1.0
	await wait_physics_ticks(1)
	source.next_input.reel = 0.0
	assert_eq(player.grapple_state, Player.GrappleState.ROPE)
	var length := player.rope_length
	await wait_physics_ticks(30)
	assert_eq(player.grapple_state, Player.GrappleState.ROPE)
	assert_almost_eq(player.rope_length, length, 0.001, "the rope should hold its length")


func test_letting_the_line_out_from_a_hang_lowers_you() -> void:
	await _attach_to_near_pipe()
	var ticks: int = await _ticks_until(_is_hanging, 180)
	assert_true(ticks >= 0, "should reach the pipe and hang")
	source.next_input.reel = -1.0
	await wait_physics_ticks(30)
	assert_eq(player.grapple_state, Player.GrappleState.ROPE)
	assert_true(player.rope_length > player.hang_distance() + 3.0, "line should grow, at %.2f m" % player.rope_length)


func _press_toggle_gravity() -> void:
	source.next_input.toggle_gravity = true
	await wait_physics_ticks(1)
	source.next_input.toggle_gravity = false
	await wait_physics_ticks(1)


func test_gravity_button_toggles_gravity_off_and_on() -> void:
	await _press_toggle_gravity()
	assert_false(match_node.gravity_enabled)
	assert_false(player.gravity_enabled)
	player.place(spawn, 0.0, 0.0)
	await wait_physics_ticks(30)
	assert_almost_eq(player.velocity, Vector3.ZERO, 0.001, "should float in place")

	await _press_toggle_gravity()
	assert_true(player.gravity_enabled)
	await wait_physics_ticks(30)
	assert_true(player.velocity.y < -4.0, "should fall again, got %.2f" % player.velocity.y)


func test_holding_the_gravity_button_toggles_once() -> void:
	source.next_input.toggle_gravity = true
	await wait_physics_ticks(10)
	assert_false(match_node.gravity_enabled)


func test_pull_back_still_works_without_gravity() -> void:
	match_node.set_gravity_enabled(false)
	player.place(Vector3(0, 0, match_node.arena.lattice.half_extent + 13.0), 0.0, 0.0)
	await wait_physics_ticks(30)
	assert_true(player.velocity.z < -1.0, "should head back toward the cube, got %s" % player.velocity)
	assert_almost_eq(player.velocity.y, 0.0, 0.001)


func test_swing_mode_lands_as_a_plain_rope() -> void:
	player.auto_reel = false
	var start_distance := spawn.distance_to(near_pipe)
	await _attach_to_near_pipe()
	assert_eq(player.grapple_state, Player.GrappleState.ROPE)
	assert_almost_eq(player.rope_length, player.global_position.distance_to(near_pipe), 0.5,
			"the rope is as long as the shot")
	await wait_physics_ticks(60)
	assert_eq(player.grapple_state, Player.GrappleState.ROPE, "still swinging, not pulled in")
	assert_true(player.global_position.distance_to(near_pipe) > start_distance - 3.0,
			"shouldn't be reeled in toward the beam")


## Rebuilds this test's arena with orbs. The player stays where they are.
func _use_orbs(size: MatchSettings.Size) -> void:
	var settings := MatchSettings.new()
	settings.zip_points = Lattice.ZipPoints.ORBS
	settings.zip_size = size
	match_node.arena.apply_settings(settings)


func test_pull_hangs_off_an_orb_outside_its_skin() -> void:
	_use_orbs(MatchSettings.Size.MEDIUM)
	var orb := spawn + Vector3.ONE * match_node.arena.spacing * 0.5 # A corner of the spawn cell.
	_aim_at(orb)
	source.next_input.grapple_held = true
	var ticks: int = await _ticks_until(_is_hanging, 240)
	assert_true(ticks >= 0, "should reach the orb and hang")
	assert_almost_eq(player.grapple_anchor_world(), orb, 0.01, "anchored at the orb's center")
	assert_almost_eq(player.global_position.distance_to(orb), 2.0 + player.tuning.hang_gap, 0.15,
			"hangs the gap away from a 2 m orb's skin")


func test_orbs_never_bump_you() -> void:
	_use_orbs(MatchSettings.Size.LARGE)
	match_node.set_gravity_enabled(false)
	var orb := spawn + Vector3.ONE * match_node.arena.spacing * 0.5
	player.place(orb + Vector3(0, 0, 8), 0.0, 0.0)
	player.velocity = Vector3(0, 0, -20)
	await wait_physics_ticks(60)
	assert_true(player.global_position.z < orb.z - 8.0, "should fly straight through, at %s" % player.global_position)
	assert_almost_eq(Vector2(player.global_position.x, player.global_position.y), Vector2(orb.x, orb.y), 0.01)
