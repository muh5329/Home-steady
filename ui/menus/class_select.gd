class_name ClassSelect
extends CanvasLayer
## Start screen: pick a class (click a card or press 1-3).

signal class_chosen(character_class: CharacterClassData)
signal continue_requested

var classes: Array[CharacterClassData] = []


func _ready() -> void:
	layer = 50
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in DataRegistry.get_all(CharacterClassData):
		classes.append(c)
	var order := [&"class.fighter", &"class.ranger", &"class.wizard"]
	classes.sort_custom(func(a, b): return order.find(a.id) < order.find(b.id))
	_build()


func choose(index: int) -> void:
	if index >= 0 and index < classes.size():
		class_chosen.emit(classes[index])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C and SaveManager.has_save():
			continue_requested.emit()
			get_viewport().set_input_as_handled()
			return
		var i: int = event.physical_keycode - KEY_1
		if i >= 0 and i < classes.size():
			choose(i)
			get_viewport().set_input_as_handled()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override(&"separation", 28)
	add_child(root)
	root.add_child(_label("HOME STEADY", 56, Color(0.98, 0.88, 0.6), true))
	root.add_child(_label("Choose your adventurer", 22, Color(0.85, 0.85, 0.85), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	root.add_child(row)
	for i in classes.size():
		row.add_child(_card(i, classes[i]))
	root.add_child(_label("Click a card or press 1–3", 16, Color(0.7, 0.7, 0.7), true))
	if SaveManager.has_save():
		var cont := Button.new()
		cont.text = "[C] Continue saved game"
		cont.focus_mode = Control.FOCUS_NONE
		cont.custom_minimum_size = Vector2(320, 44)
		cont.pressed.connect(func(): continue_requested.emit())
		var holder := CenterContainer.new()
		holder.add_child(cont)
		root.add_child(holder)


func _card(index: int, c: CharacterClassData) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 300)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	normal.border_color = c.ui_color
	normal.set_border_width_all(2)
	normal.border_width_top = 8
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.17, 0.2, 0.98)
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)
	button.pressed.connect(choose.bind(index))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = 24
	box.offset_bottom = -20
	box.add_theme_constant_override(&"separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.add_child(_label("[%d]  %s" % [index + 1, c.display_name], 30, c.ui_color.lightened(0.3)))
	var summary := _label(c.role_summary, 16, Color(0.9, 0.9, 0.88))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var weapon := c.starting_weapon.display_name if c.starting_weapon else "-"
	box.add_child(_label("Health %d   Poise %d\nWeapon: %s" % [c.max_health, c.max_poise, weapon], 15, Color(0.75, 0.75, 0.72)))
	return button


func _label(text: String, size: int, color: Color, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
