class_name MovementTuning
extends Resource
## Feel numbers for player movement and the grapple. Edit movement_tuning.tres in the
## Godot inspector. Starting values are recorded in docs/design.md, "Tuning".

@export_group("Gravity and air")
## Meters per second squared, world down.
@export var gravity := 9.8
## Air control acceleration (m/s^2) from WASD / left stick.
@export var air_accel := 8.0
## Air control stops adding speed in a direction once you're this fast in it (m/s).
@export var air_max_speed := 10.0
## When true, W/S follow where you look (including up and down). When false, they stay level.
@export var air_control_follows_pitch := false
## Overall speed cap (m/s).
@export var max_speed := 45.0
## Fraction of speed lost per second.
@export var drag := 0.02

@export_group("Grapple")
@export var grapple_range := 80.0
## How far off (degrees) you can aim and still catch a pipe. An angle, so far pipes are as
## easy to hit as near ones. 0 turns aim assist off.
@export var aim_assist_degrees := 3.0
## How fast Q/E (L2/R2) change the line length (m/s).
@export var reel_speed := 10.0
@export var min_rope_length := 1.5
@export var max_rope_length := 90.0
## Fastest the rope will yank you back to its length (m/s).
@export var max_rope_pull_speed := 25.0

@export_group("Pull (auto-reel)")
## How fast the hook flies out (m/s). Let go before it lands and the shot is cancelled.
## 0 makes it land instantly.
@export var hook_speed := 200.0
## Top speed the line pulls you toward the pipe once the hook lands (m/s). There's no gravity
## while it pulls, and if you're already going faster toward the pipe, you keep that speed.
## 0 turns the pull off: the line just holds its length and you swing.
@export var pull_speed := 30.0
## How quickly the pull gets up to pull_speed, and how hard it brakes near the pipe (m/s^2).
@export var pull_accel := 120.0
## How much of your sideways speed the pull keeps. 0 pulls you dead straight at the pipe,
## like the Q-Claw in 007: Agent Under Fire. 1 keeps it all, so the pull curves you around
## the pipe and you can fling off it.
@export_range(0.0, 1.0) var pull_keep_sideways := 0.5
## How far from the pipe's center line the pull stops and you hang (m).
@export var hang_distance := 2.0

@export_group("Pipes")
## 0 = no bounce, 1 = perfectly elastic.
@export var bounce := 0.3
## Fraction of sliding speed lost on each pipe contact.
@export var pipe_friction := 0.1

@export_group("Outside the cube")
## How far past the outer pipes you can go before the pull kicks in (m).
@export var outside_margin := 1.0
## Pull toward the cube (m/s^2), replacing gravity.
@export var pull_back_accel := 20.0
## Extra pull per meter beyond the margin (m/s^2 per m).
@export var pull_back_per_meter := 4.0
## How quickly outward speed is removed while outside (per second).
@export var pull_back_damping := 2.0
