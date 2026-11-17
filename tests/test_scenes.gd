extends "res://tools/test_case.gd"
## Catches broken scene files (easy to do when editing .tscn by hand).


func test_main_scene_runs() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed := load(main_path) as PackedScene
	assert_not_null(packed, "main scene %s failed to load" % main_path)
	if packed == null:
		return
	var main := add_to_tree(packed.instantiate())
	await wait_physics_ticks(5)
	assert_true(main.is_inside_tree(), "main scene should still be in the tree after a few ticks")


func test_every_scene_instantiates() -> void:
	for path: String in _find_scenes("res://src"):
		var packed := load(path) as PackedScene
		if packed == null:
			fail("%s failed to load" % path)
			continue
		var node := packed.instantiate()
		if node == null:
			fail("%s failed to instantiate" % path)
			continue
		node.free()


func _find_scenes(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_find_scenes(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".tscn"):
			found.append(dir_path.path_join(file))
	return found
