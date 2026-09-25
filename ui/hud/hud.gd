class_name HUD
extends CanvasLayer
## Player-facing overlay: health, interaction prompt, controls reference,
## and death message. Listens to component signals; never pulls state
## every frame.

@export var player: Player

var _health_bar: ProgressBar
var _health_label: Label
var _prompt: Label
var _controls: Label
var _banner: Label
var _resources: Label


func _ready() -> void:
	_build()
	if player == null:
		player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player:
		bind_player(player)
	EventBus.storage_changed.connect(func(_s): _refresh_resources())
	EventBus.world_geometry_changed.connect(func(): _refresh_resources.call_deferred())
	EventBus.building_completed.connect(func(b):
		_refresh_resources()
		show_banner("%s built!" % b.definition.display_name, 2.5, Color(1, 0.85, 0.4)))
	_refresh_resources.call_deferred()


func bind_player(p: Player) -> void:
	player = p
	p.health.health_changed.connect(_on_health_changed)
	_on_health_changed(p.health.current, p.health.max_health)
	p.interaction.focus_changed.connect(_on_focus_changed)
	p.interaction.carrying_changed.connect(_on_carrying_changed)
	p.combat.died.connect(func(): show_banner("You have fallen", 3.0))


func show_banner(text: String, seconds: float, color := Color(0.95, 0.3, 0.2)) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner.visible = true
	await get_tree().create_timer(seconds).timeout
	_banner.visible = false


## Settlement-wide totals across every storage.
func _refresh_resources() -> void:
	var settlement := Settlement.of(self)
	if settlement == null:
		return
	var totals := settlement.totals()
	var lines: PackedStringArray = ["Settlement",
		"  Settlers  %d   Beds  %d" % [get_tree().get_nodes_in_group(&"settlers").size(), settlement.beds()],
		"Stores"]
	if totals.is_empty():
		lines.append("  (nothing stored yet)")
	for id in totals:
		var data := DataRegistry.get_data(id) as ItemData
		lines.append("  %s  %d" % [data.display_name if data else String(id), totals[id]])
	_resources.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
		_controls.visible = not _controls.visible


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), maximum]


func _on_focus_changed(_target: Interactable) -> void:
	_update_prompt()


func _on_carrying_changed(_item: Carryable) -> void:
	_update_prompt()


func _update_prompt() -> void:
	var interaction := player.interaction
	var target := interaction.focused
	var item := interaction.carrying
	if item:
		if target and target.can_accept(item):
			_prompt.text = "[E] %s %s     [G] Drop     [LMB] Throw" % [target.deposit_verb, item.display_name()]
		else:
			_prompt.text = "[E/G] Put down %s     [LMB] Throw" % item.display_name()
	elif target:
		_prompt.text = "[E]  %s" % target.get_prompt()
	else:
		_prompt.text = ""


# --- layout ----------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.add_theme_stylebox_override(&"panel", _box(Color(0.08, 0.07, 0.06, 0.55), 6))
	root.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var title := _label("Adventurer", 16, Color(0.95, 0.88, 0.7))
	col.add_child(title)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(260, 18)
	_health_bar.show_percentage = false
	_health_bar.add_theme_stylebox_override(&"background", _box(Color(0.15, 0.05, 0.05, 0.9), 3))
	_health_bar.add_theme_stylebox_override(&"fill", _box(Color(0.78, 0.16, 0.12), 3))
	col.add_child(_health_bar)
	_health_label = _label("", 13, Color(0.9, 0.9, 0.9))
	col.add_child(_health_label)

	_prompt = _label("", 22, Color(1, 0.96, 0.85))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, -150)
	_prompt.size = Vector2(600, 40)
	root.add_child(_prompt)

	_controls = _label(
		"WASD move   Shift sprint   Alt walk   Space jump   Ctrl/C dodge\n" +
		"LMB attack (combo)   F heavy   RMB block   E interact   G drop\n" +
		"B build   R rotate   X cancel site (in build mode)   F5 save   F9 load   F3 debug   H hide help", 14, Color(0.92, 0.92, 0.88, 0.85))
	_controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.position = Vector2(24, -86)
	root.add_child(_controls)

	var res_panel := PanelContainer.new()
	res_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	res_panel.position = Vector2(-230, 24)
	res_panel.custom_minimum_size = Vector2(206, 0)
	res_panel.add_theme_stylebox_override(&"panel", _box(Color(0.08, 0.07, 0.06, 0.55), 6))
	root.add_child(res_panel)
	_resources = _label("", 15, Color(0.95, 0.9, 0.78))
	res_panel.add_child(_resources)

	_banner = _label("", 48, Color(0.95, 0.3, 0.2))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-400, -60)
	_banner.size = Vector2(800, 80)
	_banner.visible = false
	root.add_child(_banner)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = 10
	b.content_margin_right = 10
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b
