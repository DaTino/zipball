class_name PlayerInput
extends RefCounted
## One tick of input for one player. Gameplay reads only this, never the Input singleton.
## Aim is absolute (not a per-tick delta) so it can later be sent over the network as-is.

## x = strafe right, y = forward. Length is at most 1.
var move := Vector2.ZERO
## Radians around world up. 0 looks toward -Z.
var yaw := 0.0
## Radians. Positive looks up.
var pitch := 0.0
var grapple_held := false
var throw_held := false
## +1 shortens the grapple line, -1 lengthens it.
var reel := 0.0
## Prototype-only respawn button.
var respawn := false
## Testing-only button: each press turns downward gravity off or back on.
var toggle_gravity := false


func copy() -> PlayerInput:
	var c := PlayerInput.new()
	c.move = move
	c.yaw = yaw
	c.pitch = pitch
	c.grapple_held = grapple_held
	c.throw_held = throw_held
	c.reel = reel
	c.respawn = respawn
	c.toggle_gravity = toggle_gravity
	return c
