class_name BuildMenu
extends CanvasLayer
## Build mode UI: lists buildings with hotkeys and costs, shows the
## selection and why placement is blocked. Pure view over BuildMode signals.

@export var build_mode: BuildMode

var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label
var _rows: Dictionary = {}  # BuildingDefinition -> Label


func _ready() -> void:
	_build()
	_panel.visible = false
	build_mode.opened.connect(func(): _panel.visible = true)
	build_mode.closed.connect(func(): _panel.visible = false)
	build_mode.selection_changed.connect(_on_selection_changed)
	build_mode.validity_changed.connect(_on_validity_changed)


func _on_selection_changed(definition: BuildingDefinition) -> void:
	for d in _rows:
		var label: Label = _rows[d]
		label.add_theme_color_override(&"font_color",
			Color(1, 0.85, 0.35) if d == definition else Color(0.9, 0.88, 0.82))


func _on_validity_changed(valid: bool, reason: String) -> void:
	_status.text = "LMB place   R rotate   X cancel site   RMB/B close" if valid else "Can't build here: %s   (X cancels a site in front)" % reason
	_status.add_theme_color_override(&"font_color", Color(0.7, 1, 0.7) if valid else Color(1, 0.55, 0.45))


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 150)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.78)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(12)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	_panel.add_child(_list)
	_list.add_child(_label("BUILD", 20, Color(0.95, 0.88, 0.7)))
	var i := 1
	for d in build_mode.definitions():
		var row := _label("[%d] %s — %s" % [i, d.display_name, d.cost_text()], 16, Color(0.9, 0.88, 0.82))
		row.tooltip_text = d.description
		_list.add_child(row)
		_list.add_child(_label("      " + d.description, 12, Color(0.75, 0.73, 0.68)))
		_rows[d] = row
		i += 1
	_status = _label("", 15, Color(0.7, 1, 0.7))
	_list.add_child(_status)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"outline_size", 4)
	return l
