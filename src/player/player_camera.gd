class_name PlayerCamera
extends Camera3D
## First-person camera. Follows the player's interpolated position every frame and uses the
## freshest aim from the input source, so mouse look isn't held back to the tick rate.

var player: Player
var source: InputSource


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.05
	far = 4000.0
	fov = 80.0


func _process(_delta: float) -> void:
	if player == null:
		return
	var aim := source.get_live_aim() if source != null else Vector2(player.yaw, player.pitch)
	global_transform = Transform3D(Movement.aim_basis(aim.x, aim.y),
			player.get_global_transform_interpolated().origin)
