class_name ArenaSpin
extends RefCounted
## Semi-random, reproducible tumbling for the arena.
##
## Every few seconds a new target spin is picked (random axis, random speed) and the
## angular velocity blends smoothly toward it. The same seed and the same sequence of
## step() calls always produce the same spin.

var min_speed: float ## rad/s
var max_speed: float ## rad/s
var min_interval: float ## seconds between new targets
var max_interval: float
var blend_time: float ## seconds to blend into a new target

## Current angular velocity (axis * radians per second).
var angular_velocity := Vector3.ZERO

var _from := Vector3.ZERO
var _target := Vector3.ZERO
var _elapsed := 0.0
var _interval := 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int, min_degrees: float = 2.0, max_degrees: float = 6.0,
		p_min_interval: float = 6.0, p_max_interval: float = 12.0, p_blend_time: float = 3.0) -> void:
	min_speed = deg_to_rad(min_degrees)
	max_speed = deg_to_rad(max_degrees)
	min_interval = p_min_interval
	max_interval = p_max_interval
	blend_time = maxf(p_blend_time, 0.001)
	_rng.seed = seed_value
	_pick_target()
	# Start already spinning toward the first target.
	angular_velocity = _target
	_from = _target


## Advances by one tick and returns the angular velocity to apply during it.
func step(delta: float) -> Vector3:
	_elapsed += delta
	if _elapsed >= _interval:
		_from = angular_velocity
		_pick_target()
	var weight := smoothstep(0.0, 1.0, _elapsed / blend_time)
	angular_velocity = _from.lerp(_target, weight)
	return angular_velocity


func get_state() -> Dictionary:
	return {
		"angular_velocity": angular_velocity,
		"from": _from,
		"target": _target,
		"elapsed": _elapsed,
		"interval": _interval,
		"rng_state": _rng.state,
	}


func set_state(state: Dictionary) -> void:
	angular_velocity = state["angular_velocity"]
	_from = state["from"]
	_target = state["target"]
	_elapsed = state["elapsed"]
	_interval = state["interval"]
	_rng.state = state["rng_state"]


func _pick_target() -> void:
	var axis := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn())
	if axis.length_squared() < 1e-6:
		axis = Vector3.UP
	_target = axis.normalized() * _rng.randf_range(min_speed, max_speed)
	_interval = _rng.randf_range(min_interval, max_interval)
	_elapsed = 0.0
