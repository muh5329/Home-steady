class_name HUD
extends CanvasLayer
## Player-facing overlay: health, interaction prompt, controls reference,
## and death message. Listens to component signals; never pulls state
## every frame.

@export var player: Player

var _action_bar: ActionBar
var _minimap: Minimap
var _quest_title: Label
var _objectives: VBoxContainer
var _prompt: Label
var _controls: Label
var _banner: Label
var _resources: Label
var _title: Label
var _reticle: Label
var _party_box: VBoxContainer
var _party_rows: Array[Dictionary] = []  # {member, bar, status}
var _resource_timer := 0.0
var _boss_panel: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Node


var world_map: WorldMap


func _ready() -> void:
	_build()
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	add_child(world_map)
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
	EventBus.unlocked.connect(_on_unlocked)
	EventBus.boss_engaged.connect(_show_boss)
	EventBus.boss_disengaged.connect(func(b): if b == _boss: _hide_boss())
	EventBus.boss_defeated.connect(func(b):
		_hide_boss()
		show_banner("%s is destroyed" % b.display_name(), 3.5, Color(1, 0.85, 0.4)))


func bind_player(p: Player) -> void:
	player = p
	p.health.health_changed.connect(_on_health_changed)
	_on_health_changed(p.health.current, p.health.max_health)
	p.interaction.focus_changed.connect(_on_focus_changed)
	p.interaction.carrying_changed.connect(_on_carrying_changed)
	p.combat.died.connect(func(): show_banner("You have fallen", 3.0))
	_title.text = p.character_class.display_name if p.character_class else "Adventurer"
	_title.add_theme_color_override(&"font_color", p.character_class.ui_color.lightened(0.35) if p.character_class else Color(0.95, 0.88, 0.7))
	var party := p.get_node_or_null("Party") as Party
	if party:
		party.members_changed.connect(_rebuild_party.bind(party))
		_rebuild_party(party)


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
	var lines: PackedStringArray = ["Settlers %d   ·   Beds %d" % [settlement.settler_count(), settlement.beds()]]
	var stock: PackedStringArray = []
	for id in totals:
		var data := DataRegistry.get_data(id) as ItemData
		stock.append("%s %d" % [data.display_name if data else String(id), totals[id]])
	lines.append("   ·   ".join(stock) if not stock.is_empty() else "Stores empty")
	_resources.text = "\n".join(lines)


func _process(delta: float) -> void:
	_resource_timer -= delta
	if _resource_timer <= 0.0:
		_resource_timer = 1.0
		_refresh_resources()
		_refresh_objectives()
	_update_party()
	_update_boss()
	if player:
		var ranged := player.controller.is_ranged() and not player.interaction.is_carrying()
		_reticle.visible = ranged
		if ranged:
			var locked := player.controller.has_assist_target()
			_reticle.text = "( + )" if locked else "+"
			_reticle.add_theme_color_override(&"font_color", Color(1, 0.45, 0.35) if locked else Color(1, 1, 1, 0.85))
	_update_action_bar()


## Weapon and ability slots, guard orb and the readiness bar.
func _update_action_bar() -> void:
	if player == null or _action_bar == null:
		return
	var weapon := player.equipment.weapon if player.equipment else null
	var wglyph := ""
	if weapon:
		var id := String(weapon.id)
		wglyph = "bow" if id.contains("crossbow") or id.contains("bow") else ("staff" if id.contains("staff") else ("axe" if id.contains("axe") else "sword"))
	var slots: Array[Dictionary] = [{"glyph": wglyph, "ready": true}, {}, {}, {}]
	var readiness := 1.0
	if not player.abilities.abilities.is_empty():
		var a := player.abilities.abilities[0]
		var cd := player.abilities.cooldown_left(0)
		var total := maxf(a.cooldown, 0.01)
		var aid := String(a.id)
		var glyph := "shield" if aid.contains("bash") else ("volley" if aid.contains("volley") else ("nova" if aid.contains("nova") else a.display_name))
		slots[1] = {"glyph": glyph, "ready": cd <= 0.0, "cooldown": clampf(cd / total, 0.0, 1.0)}
		readiness = 1.0 - clampf(cd / total, 0.0, 1.0)
	_action_bar.slots = slots
	_action_bar.progress = readiness
	var combat := player.combat
	_action_bar.guard = combat.poise / maxf(combat.max_poise, 1.0)
	_action_bar.guard_text = "%d" % ceili(combat.poise)


## Objectives for the current chapter, from the state of the world.
func _refresh_objectives() -> void:
	if _objectives == null:
		return
	var goals: Array = []
	var has_house := false
	var has_smithy := false
	for reg in get_tree().get_nodes_in_group(BuildingRegistry.GROUP):
		for b in reg.get_children():
			if b is Building and b.definition:
				has_house = has_house or b.definition.id == &"building.house"
				has_smithy = has_smithy or b.definition.id == &"building.blacksmith"
	var crypt_cleared := Progression.is_unlocked(&"building.blacksmith")
	if not has_house:
		goals.append("Build a house for your settlers")
	if not crypt_cleared:
		goals.append("Clear the Abandoned Crypt to the north")
	elif not has_smithy:
		goals.append("Raise a Blacksmith with the Forge Rune")
	if goals.is_empty():
		goals.append("Grow the settlement")
	var labels := _objectives.get_children()
	for i in maxi(goals.size(), labels.size()):
		if i >= goals.size():
			labels[i].queue_free()
			continue
		if i < labels.size():
			(labels[i].get_child(0) as Label).text = goals[i]
		else:
			_objectives.add_child(_ribbon(goals[i], 15, false))


# --- boss bar & unlocks --------------------------------------------------------------

func _show_boss(boss: Node) -> void:
	_boss = boss
	_boss_name.text = boss.display_name()
	_boss_panel.visible = true


func _hide_boss() -> void:
	_boss = null
	_boss_panel.visible = false


func _update_boss() -> void:
	if _boss == null:
		return
	if not is_instance_valid(_boss):
		_hide_boss()
		return
	_boss_bar.max_value = _boss.health.max_health
	_boss_bar.value = _boss.health.current


func _on_unlocked(id: StringName) -> void:
	var data := DataRegistry.get_data(id)
	var what: String = data.display_name if data else String(id)
	show_banner("Unlocked: %s" % what, 4.0, Color(1, 0.8, 0.35))


# --- party frames ------------------------------------------------------------------

func _rebuild_party(party: Party) -> void:
	for c in _party_box.get_children():
		c.queue_free()
	_party_rows.clear()
	_party_box.add_child(HSeparator.new())
	for m in party.members():
		var row := VBoxContainer.new()
		row.add_theme_constant_override(&"separation", 1)
		var name_label := _label("%s · %s" % [m.settler_name, m.class_title()], 14,
			m.character_class.ui_color.lightened(0.4) if m.character_class else Color.WHITE)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 9)
		bar.show_percentage = false
		bar.add_theme_stylebox_override(&"background", _box(Color(0.15, 0.05, 0.05, 0.9), 2))
		bar.add_theme_stylebox_override(&"fill", _box(Color(0.3, 0.7, 0.3), 2))
		row.add_child(bar)
		var status := _label("", 12, Color(0.85, 0.83, 0.78))
		row.add_child(status)
		_party_box.add_child(row)
		_party_rows.append({"member": m, "bar": bar, "status": status})
	_party_box.visible = not _party_rows.is_empty()
	_update_party()


func _update_party() -> void:
	for r in _party_rows:
		var m = r.member
		if not is_instance_valid(m):
			continue
		var bar: ProgressBar = r.bar
		bar.max_value = m.health.max_health
		bar.value = m.health.current
		var status: Label = r.status
		status.text = "DOWNED — [E] to revive" if m.is_downed() else m.companion.activity
		status.add_theme_color_override(&"font_color", Color(1, 0.45, 0.35) if m.is_downed() else Color(0.85, 0.83, 0.78))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
		_controls.visible = not _controls.visible


func _on_health_changed(current: float, maximum: float) -> void:
	_action_bar.health = current / maxf(maximum, 1.0)
	_action_bar.health_text = "%d" % ceili(current)


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

	# Quest tracker: a title ribbon and objective ribbons (top left).
	var quest := VBoxContainer.new()
	quest.position = Vector2(0, 26)
	quest.add_theme_constant_override(&"separation", 6)
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest)
	var title_ribbon := _ribbon("A Home in the Valley", 19, true)
	_quest_title = title_ribbon.get_child(0) as Label
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", -18)
	title_row.add_child(title_ribbon)
	var scroll := _SunBadge.new()
	scroll.custom_minimum_size = Vector2(36, 36)
	scroll.set_script(load("res://ui/hud/scroll_badge.gd"))
	title_row.add_child(scroll)
	quest.add_child(title_row)
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override(&"separation", 5)
	quest.add_child(_objectives)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override(&"separation", 6)
	_party_box.visible = false
	var party_margin := MarginContainer.new()
	party_margin.add_theme_constant_override(&"margin_left", 18)
	party_margin.add_child(_party_box)
	quest.add_child(party_margin)

	# Minimap and settlement line (top right).
	var right_top := VBoxContainer.new()
	right_top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_top.offset_left = -300
	right_top.offset_right = -18
	right_top.offset_top = 12
	right_top.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right_top)
	var map_row := HBoxContainer.new()
	map_row.alignment = BoxContainer.ALIGNMENT_END
	map_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_top.add_child(map_row)
	# Time of day, like the references' "Sunrise" tag.
	var tod := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.94, 0.93, 0.9, 0.95)
	tsb.content_margin_left = 8
	tsb.content_margin_right = 26
	tsb.content_margin_top = 1
	tsb.content_margin_bottom = 1
	tod.add_theme_stylebox_override(&"panel", tsb)
	tod.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tod_label := Label.new()
	tod_label.text = "Afternoon"
	tod_label.add_theme_font_override(&"font", load("res://art/fonts/EBGaramond-SemiBold.woff2"))
	tod_label.add_theme_font_size_override(&"font_size", 15)
	tod_label.add_theme_color_override(&"font_color", Color(0.1, 0.09, 0.08))
	tod.add_child(tod_label)
	var sun := _SunBadge.new()
	sun.custom_minimum_size = Vector2(34, 34)
	sun.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tod_box := HBoxContainer.new()
	tod_box.add_theme_constant_override(&"separation", -14)
	tod_box.add_child(tod)
	tod_box.add_child(sun)
	var tod_margin := MarginContainer.new()
	tod_margin.add_theme_constant_override(&"margin_top", 62)
	tod_margin.add_child(tod_box)
	map_row.add_child(tod_margin)
	_minimap = Minimap.new()
	map_row.add_child(_minimap)
	_resources = _label("", 14, Color(0.96, 0.94, 0.88))
	_resources.add_theme_font_override(&"font", load("res://art/fonts/EBGaramond-SemiBold.woff2"))
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resources.autowrap_mode = TextServer.AUTOWRAP_WORD
	_resources.custom_minimum_size = Vector2(280, 0)
	right_top.add_child(_resources)

	# Key hints (right side), toggled with H.
	_controls = _label("", 1, Color.WHITE)  # visibility flag holder
	var hints := VBoxContainer.new()
	hints.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.offset_left = -260
	hints.offset_right = -18
	hints.offset_top = -40
	hints.add_theme_constant_override(&"separation", 4)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hints)
	for pair in [["Attack", "LMB"], ["Heavy Attack", "F"], ["Block / Aim", "RMB"], ["Ability", "Q"],
			["Interact", "E"], ["Dodge", "CTRL"], ["Sprint", "SHIFT"], ["Jump", "SPACE"],
			["Build", "B"], ["Party Orders", "T"], ["Zoom", "WHEEL"], ["Hide Hints", "H"]]:
		hints.add_child(_hint_row(pair[0], pair[1]))
	hints.add_child(_controls)
	_controls.visible = true
	_controls.visibility_changed.connect(func(): hints.modulate.a = 1.0 if _controls.visible else 0.0)

	# Action bar with orbs (bottom centre).
	_action_bar = ActionBar.new()
	root.add_child(_action_bar)
	_action_bar.size = _action_bar.custom_minimum_size
	_title = _label("Adventurer", 15, Color(0.95, 0.88, 0.7))
	_title.add_theme_font_override(&"font", load("res://art/fonts/Cinzel-Bold.woff2"))
	_title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(-150, -_action_bar.size.y - 22)
	_title.size = Vector2(300, 22)
	root.add_child(_title)
	# The references carry no class caption over the bar; the name stays
	# available (tests, tooltips) but is not drawn.
	_title.visible = false

	_prompt = _label("", 22, Color(1, 0.96, 0.85))
	_prompt.add_theme_font_override(&"font", load("res://art/fonts/EBGaramond-SemiBold.woff2"))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, -_action_bar.size.y - 64)
	_prompt.size = Vector2(600, 40)
	root.add_child(_prompt)

	_reticle = _label("+", 26, Color(1, 1, 1, 0.85))
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle.position = Vector2(-60, -20)
	_reticle.size = Vector2(120, 40)
	_reticle.visible = false
	root.add_child(_reticle)

	_boss_panel = VBoxContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-320, 26)
	_boss_panel.custom_minimum_size = Vector2(640, 0)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	_boss_name = _label("", 22, Color(0.9, 0.78, 1.0))
	_boss_name.add_theme_font_override(&"font", load("res://art/fonts/Cinzel-Bold.woff2"))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_panel.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(640, 16)
	_boss_bar.show_percentage = false
	_boss_bar.add_theme_stylebox_override(&"background", _box(Color(0.1, 0.04, 0.12, 0.9), 3))
	_boss_bar.add_theme_stylebox_override(&"fill", _box(Color(0.55, 0.2, 0.85), 3))
	_boss_panel.add_child(_boss_bar)
	root.add_child(_boss_panel)

	_banner = _label("", 44, Color(0.95, 0.3, 0.2))
	_banner.add_theme_font_override(&"font", load("res://art/fonts/Cinzel-Bold.woff2"))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-500, -60)
	_banner.size = Vector2(1000, 80)
	_banner.visible = false
	root.add_child(_banner)
	_refresh_objectives.call_deferred()


## A parchment ribbon with dark serif text (quest tracker).
func _ribbon(text: String, font_size: int, title: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.94, 0.9, 0.96) if title else Color(0.93, 0.92, 0.88, 0.92)
	sb.skew = Vector2(-0.18, 0)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.55, 0.5, 0.42, 0.9)
	sb.content_margin_left = 30 if title else 16
	sb.content_margin_right = 40 if title else 26
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 2)
	p.add_theme_stylebox_override(&"panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", load("res://art/fonts/Cinzel-Bold.woff2" if title else "res://art/fonts/EBGaramond-SemiBold.woff2"))
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color(0.1, 0.09, 0.08))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## "Attack  [LMB]": a white label and a key cap, right aligned.
func _hint_row(text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 17, Color(0.97, 0.96, 0.93))
	l.add_theme_font_override(&"font", load("res://art/fonts/EBGaramond-SemiBold.woff2"))
	l.add_theme_constant_override(&"outline_size", 6)
	row.add_child(l)
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.93, 0.91)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.15, 0.15, 0.15)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	cap.add_theme_stylebox_override(&"panel", sb)
	cap.custom_minimum_size = Vector2(26, 24)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := Label.new()
	k.text = key
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_theme_font_override(&"font", load("res://art/fonts/Cinzel-Bold.woff2"))
	k.add_theme_font_size_override(&"font_size", 11 if key.length() > 2 else 14)
	k.add_theme_color_override(&"font_color", Color(0.08, 0.08, 0.08))
	cap.add_child(k)
	row.add_child(cap)
	return row


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
	b.set_corner_radius_all(maxi(radius, 6))
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 7
	b.content_margin_bottom = 7
	# Panels (translucent dark fills) get the gold storybook trim.
	if color.a < 0.8 and color.v < 0.2:
		b.bg_color = Color(0.08, 0.075, 0.07, 0.86)
		b.set_border_width_all(2)
		b.border_color = Color(0.5, 0.45, 0.38, 0.95)
		b.shadow_color = Color(0, 0, 0, 0.3)
		b.shadow_size = 4
	return b


## A little sun disc for the time-of-day tag.
class _SunBadge extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 16, Color(0.12, 0.1, 0.08))
		draw_circle(c, 13, Color(0.95, 0.55, 0.15))
		draw_circle(c, 9, Color(1.0, 0.78, 0.3))
		draw_circle(c + Vector2(-3, -3), 3, Color(1, 0.95, 0.7))
