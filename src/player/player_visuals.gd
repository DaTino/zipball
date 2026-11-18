class_name PlayerVisuals
extends Node3D
## Presentation for one player: body facing, team color, grapple rope, hook and the
## marker showing where the grapple would land. Reads the simulation, never changes it.

## Where the rope leaves the player, relative to the view (right, down, forward).
const HAND_OFFSET := Vector3(0.22, -0.22, -0.3)

## The local player's input source, for the freshest aim. Null for players seen by others.
var source: InputSource
## Render layer mask for this player's body, which their own camera doesn't draw.
## The ball uses it too while they carry it. 0 until set_body_layer() is called.
var body_layers := 0

var _rope: MeshInstance3D
var _hook: MeshInstance3D
var _marker: MeshInstance3D

@onready var player: Player = get_parent()
@onready var _body: Node3D = %Body
@onready var _shell: MeshInstance3D = %Shell
@onready var _visor: MeshInstance3D = %Visor


func _ready() -> void:
	_shell.material_override = _flat_material(Teams.COLORS[player.team])
	_visor.material_override = _flat_material(Color(0.08, 0.08, 0.12))

	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.03
	rope_mesh.bottom_radius = 0.03
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 6
	rope_mesh.rings = 0
	_rope = _make_world_mesh(rope_mesh, Color(0.95, 0.95, 0.9))

	var hook_mesh := SphereMesh.new()
	hook_mesh.radius = 0.25
	hook_mesh.height = 0.5
	hook_mesh.radial_segments = 8
	hook_mesh.rings = 4
	_hook = _make_world_mesh(hook_mesh, Color(0.95, 0.95, 0.9))

	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.15
	marker_mesh.height = 0.3
	marker_mesh.radial_segments = 8
	marker_mesh.rings = 4
	_marker = _make_world_mesh(marker_mesh, Color(0.4, 1.0, 0.5))


## Puts the body on its own render layer, so this player's camera can hide it.
func set_body_layer(layer_number: int) -> void:
	body_layers = 1 << (layer_number - 1)
	_shell.layers = body_layers
	_visor.layers = body_layers


func _physics_process(_delta: float) -> void:
	# Runs after Match has simulated this tick, so the body is interpolated smoothly.
	_body.rotation = Vector3(0.0, player.yaw, 0.0)


func _process(_delta: float) -> void:
	var arena := player.arena
	if arena == null:
		return
	var arena_transform := arena.get_global_transform_interpolated()
	var eye := player.get_global_transform_interpolated().origin
	var aim := source.get_live_aim() if source != null else Vector2(player.yaw, player.pitch)
	var view := Movement.aim_basis(aim.x, aim.y)

	if player.grapple_state != Player.GrappleState.OFF:
		var hand := eye + view * HAND_OFFSET
		var hook := arena_transform * player.grapple_anchor_local
		if player.grapple_on_ball:
			var ball_center := player.ball.get_global_transform_interpolated().origin
			hook = ball_center + (hand - ball_center).normalized() * player.ball.radius
		if player.grapple_state == Player.GrappleState.FLYING:
			hook = hand + (hook - hand).normalized() * _shown_hook_travel()
		_rope.visible = true
		_place_rope(hand, hook)
		_hook.global_position = hook
		_hook.visible = true
		_marker.visible = false
	else:
		_rope.visible = false
		_hook.visible = false
		var hit := player.find_grapple_target(-view.z)
		_marker.visible = hit != null and source != null
		if hit != null:
			_marker.global_position = arena_transform * hit.anchor


## How far the flying hook has gone this frame. The simulation moves it once per tick, so
## blend from last tick's distance to this tick's, like physics interpolation does.
func _shown_hook_travel() -> float:
	var per_tick := player.tuning.hook_speed / Engine.physics_ticks_per_second
	var behind := per_tick * (1.0 - Engine.get_physics_interpolation_fraction())
	return maxf(player.hook_travel - behind, 0.0)


func _place_rope(start: Vector3, end: Vector3) -> void:
	var along := end - start
	var length := along.length()
	if length < 0.01:
		_rope.visible = false
		return
	var y_axis := along / length
	var helper := Vector3.UP if absf(y_axis.y) < 0.99 else Vector3.RIGHT
	var x_axis := y_axis.cross(helper).normalized()
	var z_axis := x_axis.cross(y_axis)
	_rope.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (start + end) * 0.5)


## A mesh placed in world space every frame (not interpolated, not moved by the player).
func _make_world_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _flat_material(color, true)
	instance.top_level = true
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	add_child(instance)
	return instance


func _flat_material(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return material
