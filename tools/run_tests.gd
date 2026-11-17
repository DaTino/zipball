extends SceneTree
## Headless test runner: runs every test_* method in res://tests/**/test_*.gd.
##
## Usage, from the project folder:
##   tools/godot.sh --headless --script res://tools/run_tests.gd
##   tools/godot.sh --headless --script res://tools/run_tests.gd -- --filter=ball
##
## A test fails if an assert fails, or if any engine or script error is logged
## while it runs (for example calling a method on null).
## Exit code 0 when at least one test ran and all passed, 1 otherwise.

const TESTS_DIR := "res://tests"


## Collects every error the engine logs, so errors fail the test that caused them.
class ErrorCollector extends Logger:
	var _mutex := Mutex.new()
	var _messages: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if rationale != "" else code
		_mutex.lock()
		_messages.append("%s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func take_messages() -> PackedStringArray:
		_mutex.lock()
		var result := _messages.duplicate()
		_messages.clear()
		_mutex.unlock()
		return result


var _errors := ErrorCollector.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run_all.call_deferred()


func _run_all() -> void:
	var filter := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")

	for message: String in _errors.take_messages():
		print("WARN  error logged before tests started: %s" % message)

	var paths := _find_test_files(TESTS_DIR)
	paths.sort()
	var passed := 0
	var failed := 0

	for path: String in paths:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL  %s: script failed to load (parse error?)" % path)
			for message: String in _errors.take_messages():
				print("        %s" % message)
			continue
		for method: Dictionary in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			var label := "%s:%s" % [path.get_file().get_basename(), test_name]
			if filter != "" and not label.contains(filter):
				continue
			var problems: PackedStringArray = await _run_test(script, test_name)
			if problems.is_empty():
				passed += 1
				print("ok    %s" % label)
			else:
				failed += 1
				print("FAIL  %s" % label)
				for problem: String in problems:
					print("        %s" % problem)

	if passed + failed == 0:
		print("No tests ran%s." % ((" (filter: %s)" % filter) if filter != "" else ""))
	else:
		print("\n%d passed, %d failed" % [passed, failed])
	OS.remove_logger(_errors)
	quit(0 if failed == 0 and passed > 0 else 1)


func _run_test(script: GDScript, test_name: String) -> PackedStringArray:
	var test: RefCounted = script.new()
	test.set("tree", self)
	_errors.take_messages()
	if test.has_method("before_each"):
		await test.call("before_each")
	await test.call(test_name)
	if test.has_method("after_each"):
		await test.call("after_each")
	test.call("free_tracked_nodes")
	# Let deferred calls run so any errors they log count against this test.
	await process_frame
	var problems: PackedStringArray = test.get("failures")
	problems.append_array(_errors.take_messages())
	return problems


func _find_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_find_test_files(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
