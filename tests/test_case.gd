class_name TestCase
extends Node
## Base class for unit and scenario tests.
##
## Every method named `test_*` is run (and awaited, so tests may wait on
## frames). Scenario tests spawn real game scenes and drive them through
## simulated input actions, exactly as a player would.

var failures: PackedStringArray = []
var _spawned: Array[Node] = []
var _held_actions: Array[StringName] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# --- assertions -------------------------------------------------------------

## Set VERBOSE_TESTS=1 to print every check with its measured values.
static var verbose := OS.get_environment("VERBOSE_TESTS") == "1"


func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	elif verbose:
		print("         ok: ", message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> bool:
	return check(absf(actual - expected) <= tolerance,
		"%s (expected %.3f ± %.3f, got %.3f)" % [message, expected, tolerance, actual])


# --- time -----------------------------------------------------------------

func wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await wait_physics_frames(ceili(seconds * Engine.physics_ticks_per_second))


## Waits until `predicate` returns true or `timeout` seconds pass.
## Returns whether the predicate became true.
func wait_until(predicate: Callable, timeout: float) -> bool:
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return predicate.call()


## Like wait_until but bounded by wall-clock time: for work on background
## threads (navmesh baking), which headless fixed-fps runs outpace.
func wait_until_realtime(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().physics_frame
		OS.delay_msec(2)
	return predicate.call()


# --- scenes -------------------------------------------------------------------

func spawn(scene_path: String, parent: Node = null) -> Node:
	var node: Node = load(scene_path).instantiate()
	(parent if parent else self).add_child(node)
	_spawned.append(node)
	return node


func cleanup() -> void:
	for action in _held_actions.duplicate():
		release(action)
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()


# --- simulated input ---------------------------------------------------------

func press(action: StringName) -> void:
	_send_action(action, true)
	if action not in _held_actions:
		_held_actions.append(action)


func release(action: StringName) -> void:
	_send_action(action, false)
	_held_actions.erase(action)


## Press and release on consecutive physics frames (a "tap").
func tap(action: StringName) -> void:
	press(action)
	await wait_physics_frames(2)
	release(action)
	await wait_physics_frames(1)


func hold(action: StringName, seconds: float) -> void:
	press(action)
	await wait_seconds(seconds)
	release(action)


## Press and release a physical key (for UI hotkeys like 1-9).
func tap_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_physics_frames(1)


func _send_action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


# --- visual capture -------------------------------------------------------------

## Saves the current frame to tests/output/<name>.png (no-op when headless).
func screenshot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(shot_name + ".png"))
	print("   [screenshot] ", shot_name)
