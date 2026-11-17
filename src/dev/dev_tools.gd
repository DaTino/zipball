extends Node
## Dev-only helpers, driven by command-line user args (the ones after `--`).
##
##   --screenshot=<path>  Wait a few frames, save the screen to a PNG, then quit.
##                        Relative paths are relative to the project folder.
##   --frames=<n>         Frames to wait before the screenshot (default 30).
##   --camera=x,y,z       Look from this world position instead of the player's view...
##   --look-at=x,y,z      ...toward this point (default 0,0,0).
##
## Example, from the project folder:
##   tools/godot.sh -- --screenshot=tmp/screenshots/main.png
##
## Does nothing when no dev args are given, so it is safe to leave enabled.

const DEFAULT_FRAMES := 30

## True while taking an automated screenshot (gameplay code uses it to skip grabbing the mouse).
var screenshot_mode := false


func _ready() -> void:
	var args := _parse_user_args()
	if args.has("camera"):
		_add_free_camera.call_deferred(_parse_vector(args["camera"]), _parse_vector(args.get("look-at", "0,0,0")))
	if args.has("screenshot"):
		screenshot_mode = true
		var frames := int(args.get("frames", str(DEFAULT_FRAMES)))
		_capture_and_quit(args["screenshot"], frames)


## A fixed camera for looking at the scene from outside. Added after the main scene's own
## cameras, so it wins.
func _add_free_camera(from: Vector3, target: Vector3) -> void:
	await get_tree().process_frame
	var camera := Camera3D.new()
	camera.far = 2000.0
	# It never moves, so don't interpolate (that would start it at the origin for a frame).
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().current_scene.add_child(camera)
	camera.look_at_from_position(from, target)
	camera.make_current()


func _parse_vector(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		push_error("[DevTools] Expected x,y,z but got '%s'" % text)
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _parse_user_args() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result


func _capture_and_quit(path: String, frames: int) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[DevTools] --screenshot needs a real window; don't combine it with --headless.")
		get_tree().quit(1)
		return
	if not path.is_absolute_path():
		path = "res://" + path
	var global_path := ProjectSettings.globalize_path(path)

	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var err := image.save_png(global_path)
	if err != OK:
		push_error("[DevTools] Could not save screenshot to %s (%s)" % [global_path, error_string(err)])
		get_tree().quit(1)
		return
	print("[DevTools] Screenshot saved: %s" % global_path)
	get_tree().quit()
