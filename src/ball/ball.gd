class_name Ball
extends CharacterBody3D
## The ball. It waits, frozen, at the faceoff spot until someone grabs it (D14). A player
## grabs a loose ball by getting close (D11), and it then rides in front of them. A player can
## also hook a loose ball with the grapple: the line reels it in until they catch it, or until
## they let go. Holding the throw button charges a throw; letting go throws the ball straight
## along the carrier's aim, at a speed set by the charge alone: the carrier's own velocity
## isn't added, so it flies where the crosshair points (D12). A loose ball flies under gravity, bounces
## off beams and is pulled back when it leaves the cube (D6), using our own movement code, like
## the players (D8). Match pins it where it is when play stops (after a goal or at the end).
##
## Match calls simulate() every tick after the players move. _process only decides who sees it.

const COLOR := Color(1.0, 0.92, 0.25)
## Gap (m) between a carrier's center and the surface of the ball they're holding.
const CARRY_GAP := 0.5
## Right after a throw, the thrower's camera skips the ball while it's this close (m), so it
## doesn't flash across their whole view as it leaves.
const HIDE_FROM_THROWER_DISTANCE := 8.0

## Gravity and the pull back into the cube, shared with the players.
@export var tuning: MovementTuning
## Ball radius (m). The menu's Ball Size sets it; 1.5 m is Medium.
@export var radius := 1.5:
	set(value):
		radius = value
		_resize()
## A player grabs a loose ball when their center gets this close to the ball's surface (m).
## Doubled from 2 m on 2026-11-17.
@export var pickup_distance := 4.0

@export_group("Throwing")
## Seconds of holding the throw button for a full-power throw.
@export var charge_time := 1.0
## Throw speed (m/s) for a quick tap. The thrower's own velocity isn't added.
@export var throw_min_speed := 15.0
## Throw speed (m/s) at full charge. Was 50 m/s on top of the thrower's velocity until 2026-11-17.
@export var throw_max_speed := 100.0
## Seconds after a throw before the thrower can grab the ball again. Others can right away.
@export var regrab_delay := 0.5

@export_group("Flight")
## 0 = no bounce off pipes, 1 = perfectly elastic.
@export var bounce := 0.6
## Fraction of sliding speed lost on each pipe contact.
@export var pipe_friction := 0.05
## Fraction of speed lost per second.
@export var drag := 0.02
## Speed cap (m/s). Above throw_max_speed, so a full throw isn't clipped.
@export var max_speed := 120.0

@export_group("Hooked")
## How fast the line reels a hooked ball toward you (m/s, on top of your own velocity).
@export var reel_speed := 60.0
## How quickly a hooked ball gets up to reel_speed (m/s^2). There's no gravity while it reels.
@export var reel_accel := 300.0

## Set by Match before the first tick.
var arena: Arena
## The player holding the ball, or null while it's loose.
var carrier: Player = null
## True while the ball waits at the faceoff spot for its first touch. It doesn't move.
var frozen := true
## Seconds the carrier has held the throw button (0 when not charging).
var throw_charge := 0.0
## Who threw it last.
var last_thrower: Player = null
## Seconds until the last thrower can grab it again.
var regrab_wait := 0.0
## Testing switch (Match sets it), like Player.gravity_enabled.
var gravity_enabled := true
## The player whose grapple has hooked the ball and is reeling it in, or null.
var reeled_by: Player = null
## The last player to grab or hook the ball since the last reset_to(), or null. A goal is an
## own goal when this player defends the goal the ball went into.
var last_touch: Player = null
## True while play is stopped (after a goal, or once the match is over): the ball stays put at
## pinned_local, turning with the cube, and nobody can grab or hook it. reset_to() ends it.
var pinned := false
## Where a pinned ball sits, in arena-local space.
var pinned_local := Vector3.ZERO

var _throw_was_held := false
var _mesh: MeshInstance3D
var _shape: SphereShape3D
var _sphere: SphereMesh


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	_shape = SphereShape3D.new()
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = _shape
	add_child(collision)

	_sphere = SphereMesh.new()
	_sphere.radial_segments = 16
	_sphere.rings = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_sphere.material = material
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = _sphere
	add_child(_mesh)
	_resize()


## One tick. `inputs[i]` is this tick's input for `players[i]`. A loose ball goes to the first
## player in range (in player order, so it's deterministic). The carrier charges and throws.
## A carried ball sits in front of its carrier; a loose one flies.
func simulate(players: Array[Player], inputs: Array[PlayerInput], delta: float) -> void:
	if pinned:
		global_position = arena.to_global(pinned_local)
		return
	regrab_wait = maxf(regrab_wait - delta, 0.0)
	if reeled_by != null and reeled_by.grapple_state != Player.GrappleState.REELING_BALL:
		reeled_by = null # They let go (or respawned).
	if carrier == null:
		_try_pick_up(players, inputs)
	if carrier != null:
		var input := inputs[players.find(carrier)]
		if input.throw_held:
			throw_charge = minf(throw_charge + delta, charge_time)
		elif _throw_was_held:
			_throw()
		_throw_was_held = input.throw_held

	if carrier != null:
		global_position = carry_position(carrier)
		velocity = carrier.velocity
	elif reeled_by != null:
		_reel(delta)
	elif not frozen:
		_fly(delta)


func can_pick_up(player: Player) -> bool:
	if pinned or _waiting_to_regrab(player):
		return false
	return player.global_position.distance_to(global_position) <= radius + pickup_distance


## Whether `player`'s grapple can hook the ball: it has to be loose and in play, and a thrower
## can't hook their own throw until they could grab it again.
func can_be_hooked_by(player: Player) -> bool:
	return carrier == null and not pinned and not _waiting_to_regrab(player)


## Called by a player's grapple when its hook reaches the ball. The newest hook wins, which
## also wakes up a ball waiting at the faceoff spot.
func hook(player: Player) -> void:
	reeled_by = player
	last_touch = player
	frozen = false


## Where a carried ball sits: just in front of the carrier, along their aim.
func carry_position(player: Player) -> Vector3:
	return player.global_position + player.aim_direction() * (radius + CARRY_GAP)


## How charged the current throw is, 0 to 1.
func charge_fraction() -> float:
	return throw_charge / charge_time if charge_time > 0.0 else 1.0


## Throw speed (m/s) for a charge from 0 to 1.
func throw_speed(fraction: float) -> float:
	return lerpf(throw_min_speed, throw_max_speed, clampf(fraction, 0.0, 1.0))


## Puts the ball, loose and frozen, at `world_position` (the faceoff spot).
func reset_to(world_position: Vector3) -> void:
	carrier = null
	frozen = true
	pinned = false
	velocity = Vector3.ZERO
	throw_charge = 0.0
	last_thrower = null
	last_touch = null
	regrab_wait = 0.0
	reeled_by = null
	_throw_was_held = false
	global_position = world_position
	reset_physics_interpolation()


## Takes the ball out of play where it is (in the goal it just touched, say): it drops from
## its carrier or line and stays there, turning with the cube, until the next reset_to().
func pin() -> void:
	var touch := last_touch
	reset_to(global_position)
	last_touch = touch
	pinned = true
	pinned_local = arena.to_local(global_position)


func _waiting_to_regrab(player: Player) -> bool:
	return player == last_thrower and regrab_wait > 0.0


func _try_pick_up(players: Array[Player], inputs: Array[PlayerInput]) -> void:
	for i: int in players.size():
		if can_pick_up(players[i]):
			carrier = players[i]
			last_touch = carrier
			frozen = false
			reeled_by = null
			throw_charge = 0.0
			_throw_was_held = inputs[i].throw_held
			return


## Straight along the aim. The ball starts on the camera's center line (carry_position), so it
## follows the crosshair; only gravity bends it after that.
func _throw() -> void:
	var thrower := carrier
	global_position = carry_position(thrower)
	velocity = thrower.aim_direction() * throw_speed(charge_fraction())
	carrier = null
	last_thrower = thrower
	regrab_wait = regrab_delay
	throw_charge = 0.0


func _fly(delta: float) -> void:
	var v := Movement.apply_environment(velocity, global_position, arena, tuning, gravity_enabled, delta)
	v *= maxf(0.0, 1.0 - drag * delta)
	velocity = v.limit_length(max_speed)
	Movement.move_and_bounce(self, bounce, pipe_friction)


## Hooked: the line pulls the ball toward whoever hooked it, with no gravity. Speeds are
## measured against theirs, so it catches up even while they fly.
func _reel(delta: float) -> void:
	var toward := (reeled_by.global_position - global_position).normalized()
	var target := reeled_by.velocity + toward * reel_speed
	velocity = velocity.move_toward(target, reel_accel * delta).limit_length(max_speed)
	Movement.move_and_bounce(self, bounce, pipe_friction)


func _process(_delta: float) -> void:
	# Hide the ball from one player's camera by putting it on their body layer, which their
	# camera doesn't draw: from the carrier (it would fill the screen), and from the thrower
	# for a moment after a throw. Everyone else still sees it.
	var hide_from := carrier
	if hide_from == null and last_thrower != null and regrab_wait > 0.0 \
			and last_thrower.global_position.distance_to(global_position) < HIDE_FROM_THROWER_DISTANCE:
		hide_from = last_thrower
	var layers := 1
	if hide_from != null:
		var visuals := hide_from.get_node(^"Visuals") as PlayerVisuals
		if visuals.body_layers != 0:
			layers = visuals.body_layers
	_mesh.layers = layers


## Sizes the collision shape and mesh to `radius` (once _ready has made them).
func _resize() -> void:
	if _shape == null:
		return
	_shape.radius = radius
	_sphere.radius = radius
	_sphere.height = radius * 2.0
