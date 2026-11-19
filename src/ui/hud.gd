class_name Hud
extends CanvasLayer
## Prototype HUD for one player: the score and clock, big banners for the faceoff countdown,
## goals and the result, a crosshair (green when the grapple would land), arrows toward the
## ball and goals, a debug readout and a controls reminder. Reads the simulation, never
## changes it.

const CONTROLS_FIRST := "Mouse / right stick: aim    WASD / left stick: steer    RMB / R1 (hold): charge a throw, let go to throw\n"
## The grapple line, for Reel mode and for Swing mode.
const CONTROLS_REEL := "LMB / L1 (hold): grapple pulls you in, then you hang; aim at the ball to reel it in. Let go to fly    E / R2: let line out    Q / L2: reel in\n"
const CONTROLS_SWING := "LMB / L1 (hold): grapple, then swing on the line; aim at the ball to reel it in. Let go to fly    Q / L2: reel in    E / R2: let out\n"
const CONTROLS_LAST := "R / Start: respawn (returns the ball to the center)    G / Back: gravity on/off    M: menu    Esc: free mouse    F11: fullscreen"

## How long "GO!" stays up once a countdown ends (s). It fades out over this time.
const GO_SECONDS := 0.8
## Height (px) of the scoreboard, kept clear of target arrows.
const SCOREBOARD_HEIGHT := 96.0
const OUTLINE := Color(0.02, 0.03, 0.1, 0.9)
const PANEL_COLOR := Color(0.05, 0.08, 0.22, 0.8)

var player: Player
var source: InputSource
var ball: Ball
## The match whose score, clock and phase this shows. Null shows no scoreboard or banners.
var match_node: Match

var _info: Label
var _hint: Label
var _crosshair: Crosshair
var _arrows := TargetArrows.new()
var _score_labels: Array[Label] = []
var _clock: Label
var _clock_caption: Label
var _banner: Label
var _banner_sub: Label
var _banner_hint: Label


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
	var grapple_line := CONTROLS_REEL if player == null or player.auto_reel else CONTROLS_SWING
	_hint.text = CONTROLS_FIRST + grapple_line + CONTROLS_LAST
	add_child(_hint)
	_arrows.reserved_bottom = -_hint.offset_top

	if match_node != null:
		_build_scoreboard()
		_build_banner()
		_arrows.reserved_top = SCOREBOARD_HEIGHT


## Shows an arrow toward a target whenever it's out of view. `locate` returns its world
## position; `shown`, if given, returns false while it should be hidden.
func track(label: String, color: Color, locate: Callable, shown := Callable()) -> void:
	_arrows.track(label, color, locate, shown)


## A clock reading such as "4:05" for a number of whole seconds.
@warning_ignore("integer_division")
static func format_clock(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	return "%d:%02d" % [seconds / 60, seconds % 60]


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
		Player.GrappleState.REELING_BALL:
			line = "reeling in the ball"
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

	if match_node != null:
		_update_scoreboard()
		_update_banner()


func _update_scoreboard() -> void:
	for team: int in _score_labels.size():
		_score_labels[team].text = str(match_node.score[team])
	var tick_rate := float(Engine.physics_ticks_per_second)
	var settings := match_node.settings
	if settings.match_rule == MatchSettings.MatchRule.POINTS:
		_clock.text = format_clock(floori(match_node.play_ticks / tick_rate))
		_clock_caption.text = "FIRST TO %d" % settings.points_to_win
	elif match_node.overtime:
		_clock.text = "+" + format_clock(floori(match_node.overtime_ticks / tick_rate))
		_clock_caption.text = "OVERTIME"
	else:
		# Round up, so it shows 0:00 only once time is really up.
		_clock.text = format_clock(ceili(match_node.time_left_ticks / tick_rate))
		_clock_caption.text = "TIME"


## The big text in the middle: the countdown, "GO!", "GOAL!" or the result.
func _update_banner() -> void:
	var tick_rate := float(Engine.physics_ticks_per_second)
	var big := ""
	var sub := ""
	var hint := ""
	var color := Color.WHITE
	var alpha := 1.0
	match match_node.phase:
		Match.Phase.COUNTDOWN:
			big = str(ceili(match_node.phase_ticks_left() / tick_rate))
			if match_node.overtime:
				sub = "OVERTIME: next goal wins"
			elif match_node.play_ticks == 0:
				sub = "Get ready"
			else:
				sub = "Faceoff"
		Match.Phase.PLAYING:
			var shown_for := match_node.phase_tick / tick_rate
			if shown_for < GO_SECONDS:
				big = "GO!"
				color = Ball.COLOR
				alpha = 1.0 - shown_for / GO_SECONDS
		Match.Phase.GOAL:
			var team := match_node.last_goal_team
			big = "GOAL!"
			color = Teams.COLORS[team]
			if match_node.last_goal_own:
				sub = "Own goal! Point to %s" % Teams.NAMES[team]
			else:
				sub = "%s scores" % Teams.NAMES[team]
		Match.Phase.OVER:
			var winner := match_node.winner
			big = "YOU WIN!" if winner == player.team else "YOU LOSE"
			color = Teams.COLORS[winner]
			var loser := Teams.opponent(winner)
			sub = "%s wins  %d - %d" % [Teams.NAMES[winner], match_node.score[winner], match_node.score[loser]]
			hint = "Press M for the menu"
	_banner.text = big
	_banner.label_settings.font_color = color
	_banner.modulate.a = alpha
	_banner_sub.text = sub
	_banner_hint.text = hint


## Top center: each team's score in its color, with the clock (or the target score) between.
func _build_scoreboard() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.offset_top = 10
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	holder.add_child(row)

	var own_team := player.team if player != null else -1
	for team: int in Teams.COLORS.size():
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _box(Teams.COLORS[team], Teams.COLORS[team].lightened(0.5)))
		box.custom_minimum_size = Vector2(84, 0)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", -6)
		box.add_child(column)
		var number := _make_banner_label(44)
		column.add_child(number)
		_score_labels.append(number)
		var name_label := _make_banner_label(14)
		name_label.text = "YOU" if team == own_team else Teams.NAMES[team].to_upper()
		column.add_child(name_label)
		row.add_child(box)
		if team == 0: # The clock sits between the two scores.
			row.add_child(_make_clock())


func _make_clock() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(PANEL_COLOR, Color(1, 1, 1, 0.3)))
	box.custom_minimum_size = Vector2(130, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -4)
	box.add_child(column)
	_clock = _make_banner_label(34)
	column.add_child(_clock)
	_clock_caption = _make_banner_label(14)
	_clock_caption.label_settings.font_color = Color(0.78, 0.87, 1.0)
	column.add_child(_clock_caption)
	return box


## The big text and a line under it, in the upper middle of the screen, clear of the
## crosshair and the markers around it. A hint (how to leave) sits below the crosshair.
func _build_banner() -> void:
	var column := VBoxContainer.new()
	column.anchor_left = 0.0
	column.anchor_right = 1.0
	column.anchor_top = 0.13
	column.anchor_bottom = 0.13
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_banner = _make_banner_label(112, 18)
	column.add_child(_banner)
	_banner_sub = _make_banner_label(30)
	column.add_child(_banner_sub)

	_banner_hint = _make_banner_label(26)
	_banner_hint.label_settings.font_color = Ball.COLOR
	_banner_hint.anchor_left = 0.0
	_banner_hint.anchor_right = 1.0
	_banner_hint.anchor_top = 0.66
	_banner_hint.anchor_bottom = 0.66
	add_child(_banner_hint)


## Centered text with a thick dark outline, in its own LabelSettings so it can change color.
func _make_banner_label(font_size: int, outline := 8) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := LabelSettings.new()
	look.font_size = font_size
	look.outline_size = outline
	look.outline_color = OUTLINE
	look.shadow_size = outline
	look.shadow_color = Color(0, 0, 0, 0.5)
	look.shadow_offset = Vector2(3, 3)
	label.label_settings = look
	return label


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 2
	box.content_margin_bottom = 6
	return box


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
