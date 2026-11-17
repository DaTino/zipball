extends "res://tools/test_case.gd"
## The arena's tumbling must be random-looking but exactly reproducible.

const DT := 1.0 / 60.0


func _run(spin: ArenaSpin, ticks: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in ticks:
		out.append(spin.step(DT))
	return out


func test_same_seed_gives_same_spin() -> void:
	assert_eq(_run(ArenaSpin.new(42), 3000), _run(ArenaSpin.new(42), 3000))


func test_different_seeds_differ() -> void:
	assert_true(_run(ArenaSpin.new(1), 600) != _run(ArenaSpin.new(2), 600))


func test_spin_changes_direction_over_time() -> void:
	var spin := ArenaSpin.new(7)
	var first := spin.step(DT)
	_run(spin, 60 * 30) # 30 seconds: at least two new targets.
	var later := spin.angular_velocity
	assert_true(first.normalized().dot(later.normalized()) < 0.999, "spin axis should drift")


func test_speed_never_exceeds_maximum() -> void:
	var spin := ArenaSpin.new(3, 2.0, 6.0)
	for w: Vector3 in _run(spin, 60 * 60):
		if rad_to_deg(w.length()) > 6.0001:
			fail("spin reached %.3f deg/s" % rad_to_deg(w.length()))
			return


func test_saved_state_replays_exactly() -> void:
	var spin := ArenaSpin.new(11)
	_run(spin, 500)
	var state := spin.get_state()
	var expected := _run(spin, 1000)
	var replay := ArenaSpin.new(999)
	replay.set_state(state)
	assert_eq(_run(replay, 1000), expected)
