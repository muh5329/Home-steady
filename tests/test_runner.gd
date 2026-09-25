extends Node
## Runs every tests/**/test_*.gd file and exits with a non-zero code on
## failure. Run headless:
##     godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn -- [filter]
## `filter` matches file names (substring) or "file:method".

const TEST_DIRS := ["res://tests/unit", "res://tests/scenarios"]
## A single test method may not run longer than this (seconds of game time).
const TEST_TIMEOUT := 300.0

var _passed := 0
var _failed := 0
var _failed_names: PackedStringArray = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	var filter := ""
	var dirs: Array = TEST_DIRS
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture":
			dirs = ["res://tests/capture"]  # visual captures need a real renderer
		elif arg != "":
			filter = arg
	var started := Time.get_ticks_msec()
	for path in _collect(dirs):
		await _run_file(path, filter)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\n==== %d passed, %d failed (%.1fs) ====" % [_passed, _failed, elapsed])
	for n in _failed_names:
		print("  FAILED: ", n)
	get_tree().quit(1 if _failed > 0 else 0)


func _collect(dirs: Array) -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			f = f.trim_suffix(".remap")
			if f.begins_with("test_") and f.ends_with(".gd"):
				files.append(dir_path.path_join(f))
	files.sort()
	return files


func _run_file(path: String, filter: String) -> void:
	var file_name := path.get_file().get_basename()
	var method_filter := ""
	if filter != "":
		var parts := filter.split(":")
		if not file_name.contains(parts[0]):
			return
		if parts.size() > 1:
			method_filter = parts[1]
	var script: Script = load(path)
	var methods: PackedStringArray = []
	for m in script.get_script_method_list():
		var mname: String = m["name"]
		if mname.begins_with("test_") and (method_filter == "" or mname.contains(method_filter)) \
				and mname not in methods:
			methods.append(mname)
	print("\n-- ", file_name)
	for mname in methods:
		var test: TestCase = script.new()
		test.name = file_name
		add_child(test)
		test.before_each()
		var watchdog := get_tree().create_timer(TEST_TIMEOUT, true, true)
		var on_timeout := _on_timeout.bind("%s:%s" % [file_name, mname])
		watchdog.timeout.connect(on_timeout)
		await test.call(mname)
		watchdog.timeout.disconnect(on_timeout)
		test.after_each()
		test.cleanup()
		if test.failures.is_empty():
			_passed += 1
			print("   PASS  ", mname)
		else:
			_failed += 1
			_failed_names.append("%s:%s" % [file_name, mname])
			print("   FAIL  ", mname)
			for f in test.failures:
				print("         - ", f)
		test.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame


func _on_timeout(test_name: String) -> void:
	print("   TIMEOUT  ", test_name, " exceeded ", TEST_TIMEOUT, "s")
	get_tree().quit(2)
