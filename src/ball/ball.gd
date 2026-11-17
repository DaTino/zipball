class_name Ball
extends CharacterBody3D
## The ball. It waits, frozen, at the faceoff spot until someone grabs it (D14). A player
## grabs a loose ball by getting close (D11), and it then rides in front of them. Holding the
## throw button charges a throw; letting go throws the ball along the carrier's aim, on top of
## their own velocity (D12). A loose ball flies under gravity, bounces off pipes and is pulled
## back when it leaves the cube (D6), using our own movement code, like the players (D8).
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
## Ball radius (m). Tripled from 0.5 m on 2026-11-13 so it's easier to see and grab.
@export var radius := 1.5
## A player grabs a loose ball when their center gets this close to the ball's surface (m).
@export var pickup_distance := 2.0

@export_group("Throwing")
## Seconds of holding the throw button for a full-power throw.
@export var charge_time := 1.0
## Throw speed (m/s) for a quick tap, on top of the thrower's own velocity.
@export var throw_min_speed := 15.0
## Throw speed (m/s) at full charge, on top of the thrower's own velocity.
@export var throw_max_speed := 50.0
## Seconds after a throw before the thrower can grab the ball again. Others can right away.
@export var regrab_delay := 0.5

@export_group("Flight")
## 0 = no bounce off pipes, 1 = perfectly elastic.
@export var bounce := 0.6
## Fraction of sliding speed lost on each pipe contact.
@export var pipe_friction := 0.05
## Fraction of speed lost per second.
@export var drag := 0.02
## Speed cap (m/s).
@export var max_speed := 80.0

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

var _throw_was_held := false
var _mesh: MeshInstance3D


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	add_child(collision)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mesh.material = material
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = mesh
	add_child(_mesh)


## One tick. `inputs[i]` is this tick's input for `players[i]`. A loose ball goes to the first
## player in range (in player order, so it's deterministic). The carrier charges and throws.
## A carried ball sits in front of its carrier; a loose one flies.
func simulate(players: Array[Player], inputs: Array[PlayerInput], delta: float) -> void:
	regrab_wait = maxf(regrab_wait - delta, 0.0)
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
	elif not frozen:
		_fly(delta)


func can_pick_up(player: Player) -> bool:
	if player == last_thrower and regrab_wait > 0.0:
		return false
	return player.global_position.distance_to(global_position) <= radius + pickup_distance


## Where a carried ball sits: just in front of the carrier, along their aim.
func carry_position(player: Player) -> Vector3:
	return player.global_position + player.aim_direction() * (radius + CARRY_GAP)


## How charged the current throw is, 0 to 1.
func charge_fraction() -> float:
	return throw_charge / charge_time if charge_time > 0.0 else 1.0


## Throw speed (m/s, before the thrower's velocity is added) for a charge from 0 to 1.
func throw_speed(fraction: float) -> float:
	return lerpf(throw_min_speed, throw_max_speed, clampf(fraction, 0.0, 1.0))


## Puts the ball, loose and frozen, at `world_position` (the faceoff spot).
func reset_to(world_position: Vector3) -> void:
	carrier = null
	frozen = true
	velocity = Vector3.ZERO
	throw_charge = 0.0
	last_thrower = null
	regrab_wait = 0.0
	_throw_was_held = false
	global_position = world_position
	reset_physics_interpolation()


func _try_pick_up(players: Array[Player], inputs: Array[PlayerInput]) -> void:
	for i: int in players.size():
		if can_pick_up(players[i]):
			carrier = players[i]
			frozen = false
			throw_charge = 0.0
			_throw_was_held = inputs[i].throw_held
			return


func _throw() -> void:
	var thrower := carrier
	global_position = carry_position(thrower)
	velocity = thrower.velocity + thrower.aim_direction() * throw_speed(charge_fraction())
	carrier = null
	last_thrower = thrower
	regrab_wait = regrab_delay
	throw_charge = 0.0


func _fly(delta: float) -> void:
	var v := Movement.apply_environment(velocity, global_position, arena, tuning, gravity_enabled, delta)
	v *= maxf(0.0, 1.0 - drag * delta)
	velocity = v.limit_length(max_speed)
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
