extends CanvasLayer
## Developer overlay (toggle with F3): performance counters, watched values
## published by gameplay code, and short-lived notifications.
##
##     DebugOverlay.watch("player.state", state_name)
##     DebugOverlay.notify("Saved")

const NOTIFY_SECONDS := 2.5
const REFRESH_SECONDS := 0.25

var _watches: Dictionary = {}  # String -> Variant
var _notes: Array = []  # [{text, t}]
var _panel: Label
var _toast: Label
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = _make_label(Vector2(0, 12), 14)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -330
	_panel.offset_right = -12
	_panel.visible = false  # F3 toggles
	_toast = _make_label(Vector2(12, 0), 18)
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -120
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		_panel.visible = not _panel.visible


func watch(key: String, value: Variant) -> void:
	_watches[key] = value


func unwatch(key: String) -> void:
	_watches.erase(key)


func notify(text: String) -> void:
	_notes.append({"text": text, "t": NOTIFY_SECONDS})
	print("[notify] ", text)


func _process(delta: float) -> void:
	for note in _notes:
		note.t -= delta
	_notes = _notes.filter(func(n): return n.t > 0.0)
	_toast.text = "\n".join(_notes.map(func(n): return n.text))

	_refresh_timer -= delta
	if not _panel.visible or _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_SECONDS
	var lines: PackedStringArray = [
		"FPS %d  (%.1f ms)" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1)],
		"Draw calls %d   Objects %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)],
		"Nodes %d   Mem %.1f MB" % [
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0],
		"",
	]
	for key in _watches:
		lines.append("%s: %s" % [key, str(_watches[key])])
	_panel.text = "\n".join(lines)


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
