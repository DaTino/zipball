extends "res://tools/test_case.gd"
## The HUD's score, clock and banners. It only reads the match, so these tests set the
## match's state directly and check what the HUD shows.

const MATCH_SCENE := preload("res://src/match/match.tscn")

var match_node: Match
var hud: Hud


func before_each() -> void:
	match_node = MATCH_SCENE.instantiate() as Match
	match_node.auto_add_local_player = false
	add_to_tree(match_node)
	match_node.arena.spin_enabled = false
	match_node.add_player(ScriptedInputSource.new(), 0, true)
	hud = match_node.find_children("*", "Hud", false, false)[0] as Hud


## Every bit of text the HUD shows right now.
func _texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Node in hud.find_children("*", "Label", true, false):
		var text := (label as Label).text
		if text != "" and (label as Label).is_visible_in_tree():
			texts.append(text)
	return texts


func _assert_shows(text: String) -> void:
	assert_true(_texts().has(text), "the HUD should show '%s', shows %s" % [text, _texts()])


func test_clock_format() -> void:
	assert_eq(Hud.format_clock(300), "5:00")
	assert_eq(Hud.format_clock(65), "1:05")
	assert_eq(Hud.format_clock(9), "0:09")
	assert_eq(Hud.format_clock(-3), "0:00")


func test_opening_countdown_score_and_clock() -> void:
	await wait_physics_ticks(1)
	_assert_shows("3")
	_assert_shows("Get ready")
	_assert_shows("5:00")
	_assert_shows("YOU")
	_assert_shows("ORANGE")
	assert_eq(_texts().count("0"), 2, "both scores at 0")


func test_goal_banner() -> void:
	match_node.phase = Match.Phase.GOAL
	match_node.score[1] = 1
	match_node.last_goal_team = 1
	match_node.last_goal_own = true
	await wait_physics_ticks(1)
	_assert_shows("GOAL!")
	_assert_shows("Own goal! Point to Orange")
	_assert_shows("1")


func test_overtime_and_points_clocks() -> void:
	match_node.phase = Match.Phase.PLAYING
	match_node.phase_tick = 1000
	match_node.overtime = true
	match_node.overtime_ticks = 75 * Engine.physics_ticks_per_second
	await wait_physics_ticks(1)
	_assert_shows("+1:15")
	_assert_shows("OVERTIME")

	match_node.settings.match_rule = MatchSettings.MatchRule.POINTS
	match_node.settings.points_to_win = 7
	await wait_physics_ticks(1)
	_assert_shows("FIRST TO 7")


func test_result_screen() -> void:
	match_node.phase = Match.Phase.OVER
	match_node.winner = 1
	match_node.score[0] = 2
	match_node.score[1] = 3
	await wait_physics_ticks(1)
	_assert_shows("YOU LOSE")
	_assert_shows("Orange wins  3 - 2")
	_assert_shows("Press M for the menu")
