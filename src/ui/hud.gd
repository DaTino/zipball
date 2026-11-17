class_name Hud
extends CanvasLayer
## Prototype HUD for one player: crosshair (green when the grapple would land), arrows
## toward the ball and goals, a debug readout and a controls reminder. Reads the
## simulation, never changes it.

const CONTROLS_HINT := "Mouse / right stick: aim    WASD / left stick: steer    RMB / R1 (hold): charge a throw, let go to throw\nLMB / L1 (hold): grapple pulls you in, then you hang. Let go to fly    E / R2: let line out and swing    Q / L2: reel in\nR / Start: respawn (returns the ball to the center)    G / Back: gravity on/off    Esc: free mouse    F11: fullscreen"

var player: Player
var source: InputSource
var ball: Ball

var _info: Label
var _hint: Label
var _crosshair: Crosshair
var _arrows := TargetArrows.new()


## Small cross that turns green when the grapple has something to hit. While you have the
## ball, a bar under it shows how charged your throw is.
class Crosshair:
	extends Control

	const BAR_SIZE := Vector2(64, 6)

	var has_target := false:
		set(value):
			if value != has_target:
				has_target = value
				queue_redraw()
	## Throw charge from 0 to 1, or -1 when you don't have the ball (no bar).
	var charge := -1.0:
		set(value):
			if value != charge:
				charge = value
				queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var color := Color(0.4, 1.0, 0.5) if has_target else Color(1.0, 1.0, 1.0, 0.6)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + direction * 5.0, c + direction * 12.0, color, 2.0)
		draw_circle(c, 1.5, color)
		if charge >= 0.0:
			var bar := Rect2(c + Vector2(-BAR_SIZE.x * 0.5, 22.0), BAR_SIZE)
			draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(bar.position, Vector2(BAR_SIZE.x * charge, BAR_SIZE.y)), Ball.COLOR)


func _ready() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)
	add_child(_arrows)

	_info = _make_label()
	_info.position = Vector2(16, 12)
	add_child(_info)

	_hint = _make_label()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 16
	_hint.offset_top = -80
	_hint.text = CONTROLS_HINT
	add_child(_hint)
	_arrows.reserved_bottom = -_hint.offset_top


## Shows an arrow toward a target whenever it's out of view. `locate` returns its world
## position; `shown`, if given, returns false while it should be hidden.
func track(label: String, color: Color, locate: Callable, shown := Callable()) -> void:
	_arrows.track(label, color, locate, shown)


func _process(_delta: float) -> void:
	if player == null or player.arena == null:
		return
	var aim := source.get_live_aim() if source != null else Vector2(player.yaw, player.pitch)
	var looking := -Movement.aim_basis(aim.x, aim.y).z
	_crosshair.has_target = player.grapple_state != Player.GrappleState.OFF \
			or player.find_grapple_target(looking) != null

	var line := "-"
	match player.grapple_state:
		Player.GrappleState.FLYING:
			line = "hook flying"
		Player.GrappleState.PULLING:
			line = "pulling, %.1f m" % player.rope_length
		Player.GrappleState.HANGING:
			line = "hanging"
		Player.GrappleState.ROPE:
			line = "rope, %.1f m" % player.rope_length
	var ball_state := "-"
	if ball != null:
		ball_state = "loose" if ball.carrier == null else ("YOURS" if ball.carrier == player else "taken")
	_crosshair.charge = ball.charge_fraction() if ball != null and ball.carrier == player else -1.0
	_info.text = "Speed  %.1f m/s\nLine   %s\nBall   %s\nGravity  %s\nArena spin  %.1f deg/s\n%d FPS" % [
		player.velocity.length(),
		line,
		ball_state,
		"on" if player.gravity_enabled else "OFF (G / Back)",
		rad_to_deg(player.arena.angular_velocity.length()),
		Engine.get_frames_per_second(),
	]


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
