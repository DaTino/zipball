class_name Match
extends Node3D
## Runs the game simulation. Every physics tick: step the arena, then for each player poll
## their input source and simulate them, always in the same order, then the ball, then the
## match rules: goals (D13), the faceoff countdown (D14) and the clock (D15). Also spawns
## players and gives local players a camera and HUD.
##
## All match state is plain variables counted in ticks, so it's easy to save and restore.

## Goals and the end of the match. The HUD reads the state instead; these are for later
## presentation such as sound.
signal goal_scored(team: int, own_goal: bool)
signal match_ended(winning_team: int)

## Where the match stands. phase_tick counts the ticks since the phase began.
enum Phase {
	## Before kickoff and after each goal: the ball waits at the center, and players wait at
	## their spawns, facing it. They can look around but can't move or grapple.
	COUNTDOWN,
	## Normal play. Goals count, and the clock runs.
	PLAYING,
	## A short pause after a goal: the ball sits in the goal, players fly freely, nothing scores.
	## A faceoff follows.
	GOAL,
	## The match is decided. Players can still fly and look around; nothing scores.
	OVER,
}

const PLAYER_SCENE := preload("res://src/player/player.tscn")
## Loaded by path when needed, not preloaded: the menu preloads this scene.
const MENU_SCENE_PATH := "res://src/ui/main_menu.tscn"
## Render layer for player i's body is FIRST_BODY_LAYER + i, so their own camera can hide it.
const FIRST_BODY_LAYER := 11

## Off in tests, which add scripted players themselves.
@export var auto_add_local_player := true
## Start with a faceoff countdown. Off in tests that don't want to wait: the match starts in play.
@export var opening_countdown := true
## The menu's choices. Set before the match enters the tree; the defaults if left empty.
@export var settings: MatchSettings
## Length of the faceoff countdown (s).
@export var countdown_seconds := 3.0
## Pause between a goal and the faceoff that follows (s): the GOAL! banner.
@export var goal_pause_seconds := 2.0

var players: Array[Player] = []
var sources: Array[InputSource] = []
## Testing switch for downward gravity, shared by everyone in the match.
var gravity_enabled := true
## The venue's sky, light, floor and weather (presentation only).
var scenery: Scenery

var phase := Phase.PLAYING
## Ticks since the current phase began.
var phase_tick := 0
## Points per team.
var score: Array[int] = [0, 0]
## Timed matches: ticks of regulation time left. The clock runs only during play.
var time_left_ticks := 0
## Ticks of play so far, not counting countdowns and goal pauses.
var play_ticks := 0
## True once a timed match ended its regulation time tied. The next goal wins.
var overtime := false
## Ticks of overtime play so far.
var overtime_ticks := 0
## The winning team once the match is over, or -1.
var winner := -1
## The team that got the last goal's point, or -1 before the first goal.
var last_goal_team := -1
## Whether the last goal was an own goal (the other team put it in).
var last_goal_own := false

## Each player's input from the previous tick, for spotting button presses.
var _last_inputs: Array[PlayerInput] = []

@onready var arena: Arena = %Arena
@onready var ball: Ball = %Ball


func _ready() -> void:
	if settings == null:
		settings = MatchSettings.new()
	scenery = settings.make_scenery()
	add_child(scenery)
	move_child(scenery, 0)
	arena.apply_settings(settings, scenery)
	ball.radius = settings.ball_radius()
	gravity_enabled = settings.gravity
	ball.arena = arena
	ball.gravity_enabled = gravity_enabled
	ball.reset_to(faceoff_position())
	time_left_ticks = settings.time_limit_minutes * 60 * Engine.physics_ticks_per_second
	if opening_countdown:
		_start_faceoff()
	if auto_add_local_player:
		add_player(LocalInputSource.new(), 0, true)


func _physics_process(delta: float) -> void:
	arena.step(delta)
	for i: int in players.size():
		var input := sources[i].poll()
		var last := _last_inputs[i]
		if input.respawn and not last.respawn:
			respawn(i)
		if input.toggle_gravity and not last.toggle_gravity:
			set_gravity_enabled(not gravity_enabled)
		_last_inputs[i] = input
		players[i].simulate(input, delta)
	if phase != Phase.COUNTDOWN: # The ball waits at the center, frozen, until play starts.
		ball.simulate(players, _last_inputs, delta) # _last_inputs now holds this tick's inputs.
	_step_rules()


## The match rules, once per tick after everything has moved: goals, the clock, and moving
## from one phase to the next.
func _step_rules() -> void:
	phase_tick += 1
	match phase:
		Phase.COUNTDOWN:
			if phase_tick >= seconds_to_ticks(countdown_seconds):
				_set_phase(Phase.PLAYING)
		Phase.PLAYING:
			var goal_team := goal_touched()
			if goal_team >= 0:
				_score(Teams.opponent(goal_team), ball.last_touch != null and ball.last_touch.team == goal_team)
			else:
				_run_clock()
		Phase.GOAL:
			if phase_tick >= seconds_to_ticks(goal_pause_seconds):
				_start_faceoff()


## The team whose goal the ball is touching, or -1. The goals turn with the arena. Even the
## fastest ball moves only about 2 m per tick, far less than a goal's width, so it can't skip
## through one between ticks.
func goal_touched() -> int:
	for team: int in Teams.COLORS.size():
		var goal := arena.to_global(arena.goal_local_position(team))
		if ball.global_position.distance_to(goal) <= arena.goal_radius + ball.radius:
			return team
	return -1


## A point for `team`. The ball stays where it scored. Then a pause and a faceoff, unless
## that point won the match.
func _score(team: int, own_goal: bool) -> void:
	score[team] += 1
	last_goal_team = team
	last_goal_own = own_goal
	ball.pin()
	goal_scored.emit(team, own_goal)
	var reached_target := settings.match_rule == MatchSettings.MatchRule.POINTS \
			and score[team] >= settings.points_to_win
	if overtime or reached_target:
		_end(team)
	else:
		_set_phase(Phase.GOAL)


## One tick of play on the clock. A timed match ends when regulation runs out, the instant it
## does, whatever the ball is doing; a tie goes to overtime, which starts with a faceoff.
func _run_clock() -> void:
	play_ticks += 1
	if settings.match_rule != MatchSettings.MatchRule.TIMED:
		return
	if overtime:
		overtime_ticks += 1
		return
	time_left_ticks = maxi(time_left_ticks - 1, 0)
	if time_left_ticks > 0:
		return
	if score[0] == score[1]:
		overtime = true
		_start_faceoff()
	else:
		_end(0 if score[0] > score[1] else 1)


func _end(team: int) -> void:
	winner = team
	ball.pin()
	_set_phase(Phase.OVER)
	match_ended.emit(team)


## The ball frozen at the center and everyone back at their spawn facing it, then the countdown.
func _start_faceoff() -> void:
	ball.reset_to(faceoff_position())
	_set_phase(Phase.COUNTDOWN)
	for i: int in players.size():
		_place_at_spawn(i)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_tick = 0
	for player: Player in players:
		player.held = phase == Phase.COUNTDOWN


## Whole ticks in `seconds`, at the configured tick rate.
func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


## Ticks left in a countdown or goal pause (0 in other phases).
func phase_ticks_left() -> int:
	match phase:
		Phase.COUNTDOWN:
			return maxi(seconds_to_ticks(countdown_seconds) - phase_tick, 0)
		Phase.GOAL:
			return maxi(seconds_to_ticks(goal_pause_seconds) - phase_tick, 0)
	return 0


## Where the ball waits for a faceoff: the cube's center.
func faceoff_position() -> Vector3:
	return arena.global_position


## Testing switch: turns downward gravity off or on for every player and the ball. The pull back into
## the cube still works either way.
func set_gravity_enabled(enabled: bool) -> void:
	gravity_enabled = enabled
	ball.gravity_enabled = enabled
	for player: Player in players:
		player.gravity_enabled = enabled


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif key.physical_keycode == KEY_M:
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE_PATH)


## Adds a player driven by `source`. With `local_view`, they also get a camera and HUD.
func add_player(source: InputSource, team: int, local_view := false) -> Player:
	var index := players.size()
	add_child(source)
	var player := PLAYER_SCENE.instantiate() as Player
	player.team = team
	player.arena = arena
	player.ball = ball
	player.gravity_enabled = gravity_enabled
	player.auto_reel = settings.grapple_mode == MatchSettings.GrappleMode.REEL
	add_child(player)
	players.append(player)
	sources.append(source)
	_last_inputs.append(PlayerInput.new())

	var body_layer := FIRST_BODY_LAYER + index
	var visuals := player.get_node("Visuals") as PlayerVisuals
	visuals.set_body_layer(body_layer)
	_place_at_spawn(index)

	if local_view:
		visuals.source = source
		var camera := PlayerCamera.new()
		camera.player = player
		camera.source = source
		camera.cull_mask &= ~(1 << (body_layer - 1))
		add_child(camera)
		camera.make_current()
		var hud := Hud.new()
		hud.player = player
		hud.source = source
		hud.ball = ball
		hud.match_node = self
		add_child(hud)
		_track_targets(hud, player)
	return player


## HUD arrows toward the ball (unless you're carrying it) and both goals. The goals turn
## with the arena.
func _track_targets(hud: Hud, player: Player) -> void:
	var team := player.team
	var opponent := Teams.opponent(team)
	var locate_ball := func() -> Vector3: return ball.get_global_transform_interpolated().origin
	var ball_loose_or_theirs := func() -> bool: return ball.carrier != player
	hud.track("BALL", Ball.COLOR, locate_ball, ball_loose_or_theirs)
	hud.track("THEIR GOAL", Teams.COLORS[opponent], func() -> Vector3:
		return arena.get_global_transform_interpolated() * arena.goal_local_position(opponent))
	hud.track("YOUR GOAL", Teams.COLORS[team], func() -> Vector3:
		return arena.get_global_transform_interpolated() * arena.goal_local_position(team))


## Puts a player back at their team's spawn point, facing the cube's center. If they had the
## ball, it goes back to the faceoff spot.
func respawn(index: int) -> void:
	if ball.carrier == players[index]:
		ball.reset_to(faceoff_position())
	_place_at_spawn(index)


## A player at their team's spawn point, facing the faceoff spot, with no speed and no grapple.
## During a countdown, they're held there.
func _place_at_spawn(index: int) -> void:
	var player := players[index]
	var spawn_local := arena.spawn_local_position(player.team)
	var spawn := arena.to_global(spawn_local)
	var aim := Movement.aim_toward(faceoff_position() - spawn)
	player.place(spawn, aim.x, aim.y)
	sources[index].set_aim(aim.x, aim.y)
	player.hold_local = spawn_local
	player.held = phase == Phase.COUNTDOWN
