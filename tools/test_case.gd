extends RefCounted
## Base class for headless tests (see tools/run_tests.gd).
##
## Test files live under res://tests/, are named test_*.gd, start with
## `extends "res://tools/test_case.gd"`, and define methods named test_*.
## Each test method runs on a fresh instance and may use `await`.
## Optional hooks: before_each() and after_each().

## The running SceneTree, for tests that need to add nodes or wait for frames.
var tree: SceneTree
var failures: PackedStringArray = []
var _tracked_nodes: Array[Node] = []


## Adds a node under the scene root; it is freed automatically after the test.
func add_to_tree(node: Node) -> Node:
	tree.root.add_child(node)
	_tracked_nodes.append(node)
	return node


## Waits until `count` more physics ticks have fully run (for tests that simulate).
## physics_frame fires at the start of a tick, so the final process_frame await makes
## sure the last tick has finished before the test continues.
func wait_physics_ticks(count: int) -> void:
	for i: int in count:
		await tree.physics_frame
	await tree.process_frame


func free_tracked_nodes() -> void:
	for node: Node in _tracked_nodes:
		if is_instance_valid(node):
			node.free()
	_tracked_nodes.clear()


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message := "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message := "expected false") -> void:
	if condition:
		fail(message)


func assert_not_null(value: Variant, message := "expected a value, got null") -> void:
	if value == null:
		fail(message)


func assert_null(value: Variant, message := "") -> void:
	if value != null:
		fail(message if message != "" else "expected null, got %s" % [value])


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		fail("%sexpected %s, got %s" % [_prefix(message), var_to_str(expected), var_to_str(actual)])


## Approximate comparison for floats, Vector2 and Vector3.
func assert_almost_eq(actual: Variant, expected: Variant, tolerance := 0.0001, message := "") -> void:
	var diff: float
	if (actual is float or actual is int) and (expected is float or expected is int):
		diff = absf(float(actual) - float(expected))
	elif (actual is Vector2 and expected is Vector2) or (actual is Vector3 and expected is Vector3):
		diff = (actual - expected).length()
	else:
		fail("%scan't compare %s with %s" % [_prefix(message), type_string(typeof(actual)), type_string(typeof(expected))])
		return
	if diff > tolerance:
		fail("%sexpected %s ± %s, got %s" % [_prefix(message), var_to_str(expected), tolerance, var_to_str(actual)])


func _prefix(message: String) -> String:
	return message + ": " if message != "" else ""
