class_name Match
extends Node3D
## Runs the game simulation. Every physics tick: step the arena, then for each player poll
## their input source and simulate them, always in the same order. Also spawns players and
## gives local players a camera and HUD.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
## Render layer for player i's body is FIRST_BODY_LAYER + i, so their own camera can hide it.
const FIRST_BODY_LAYER := 11

## Off in tests, which add scripted players themselves.
@export var auto_add_local_player := true

var players: Array[Player] = []
var sources: Array[InputSource] = []
## Testing switch for downward gravity, shared by everyone in the match.
var gravity_enabled := true
## Each player's input from the previous tick, for spotting button presses.
var _last_inputs: Array[PlayerInput] = []

@onready var arena: Arena = %Arena
@onready var ball: Ball = %Ball


func _ready() -> void:
	ball.arena = arena
	ball.gravity_enabled = gravity_enabled
	ball.reset_to(faceoff_position())
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
	ball.simulate(players, _last_inputs, delta) # _last_inputs now holds this tick's inputs.


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
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Adds a player driven by `source`. With `local_view`, they also get a camera and HUD.
func add_player(source: InputSource, team: int, local_view := false) -> Player:
	var index := players.size()
	add_child(source)
	var player := PLAYER_SCENE.instantiate() as Player
	player.team = team
	player.arena = arena
	player.gravity_enabled = gravity_enabled
	add_child(player)
	players.append(player)
	sources.append(source)
	_last_inputs.append(PlayerInput.new())

	var body_layer := FIRST_BODY_LAYER + index
	var visuals := player.get_node("Visuals") as PlayerVisuals
	visuals.set_body_layer(body_layer)
	respawn(index)

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
	var player := players[index]
	if ball.carrier == player:
		ball.reset_to(faceoff_position())
	var spawn := arena.to_global(arena.spawn_local_position(player.team))
	var aim := Movement.aim_toward(arena.global_position - spawn)
	player.place(spawn, aim.x, aim.y)
	sources[index].set_aim(aim.x, aim.y)
