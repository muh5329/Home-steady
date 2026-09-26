class_name TalkPanel
extends CanvasLayer
## Conversation with a settler or stranger: recruit, join/leave the party,
## give orders, pick a job. Opens on EventBus.talk_requested; options are
## numbered (keys 1-9) and clickable. The world keeps running; the player's
## controls pause while it's open, and getting hurt (or loading a save)
## ends the conversation.

signal opened(speaker: Settler)
signal closed

## The conversation ends if the player is pushed/moved this far from where
## it started (settlers may wander off to work meanwhile; that's fine).
const MAX_PLAYER_DRIFT := 3.0

var speaker: Settler
var _open := false
var _player_anchor := Vector3.ZERO
var _options: Array[Dictionary] = []  # {text, action: Callable, blocked: String, keep_open}

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _line: Label
var _list: VBoxContainer
var _blocker: Control


func _ready() -> void:
	layer = 20
	_build()
	_blocker.visible = false
	EventBus.talk_requested.connect(func(s): if s is Settler: open(s))
	EventBus.game_loaded.connect(func(_slot): close())


## Note: a freed speaker still compares == null only through
## is_instance_valid, so every check uses that.
func is_open() -> bool:
	return _open


func open(who: Settler) -> void:
	if _open:
		_disconnect()
	speaker = who
	_open = true
	speaker.mode_changed.connect(_on_speaker_changed)
	speaker.combat.died.connect(close)
	var p := _player()
	if p:
		_player_anchor = p.global_position
	if p and not p.combat.receiver.damage_taken.is_connected(_on_player_hurt):
		p.combat.receiver.damage_taken.connect(_on_player_hurt)
	_set_player_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild()
	_blocker.visible = true
	opened.emit(who)


func close() -> void:
	if not _open:
		return
	_disconnect()
	speaker = null
	_open = false
	_blocker.visible = false
	var p := _player()
	if p and p.combat.receiver.damage_taken.is_connected(_on_player_hurt):
		p.combat.receiver.damage_taken.disconnect(_on_player_hurt)
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Re-enable next moment, so the key that closed us doesn't also act.
	get_tree().create_timer(0.1).timeout.connect(func(): if not _open: _set_player_input(true))
	closed.emit()


## Runs option `index` (0-based) if it's available.
func choose(index: int) -> void:
	if not _open or not is_instance_valid(speaker) or index < 0 or index >= _options.size():
		return
	var o := _options[index]
	if o.blocked != "":
		return
	o.action.call()
	if not _open:
		return
	if o.keep_open:
		_rebuild()
	else:
		close()


func option_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for o in _options:
		out.append(o.text)
	return out


func _process(_delta: float) -> void:
	if not _open:
		return
	var player := _player()
	if not is_instance_valid(speaker) or player == null or not player.combat.is_alive():
		close()
		return
	_subtitle.text = _subtitle_text()
	if player.global_position.distance_to(_player_anchor) > MAX_PLAYER_DRIFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.physical_keycode - KEY_1
		if i >= 0 and i < 9:
			choose(i)
			get_viewport().set_input_as_handled()


# --- content -------------------------------------------------------------------------

func _rebuild() -> void:
	var s := speaker
	_options.clear()
	_title.text = "%s — %s" % [s.settler_name, s.class_title()]
	if s.character_class:
		_title.add_theme_color_override(&"font_color", s.character_class.ui_color.lightened(0.4))
	_subtitle.text = _subtitle_text()
	match s.mode:
		Settler.Mode.STRANGER:
			_line.text = "\"%s\"" % (s.greeting if s.greeting != "" else "Well met, traveller.")
			_add("Invite %s to live in the settlement" % s.settler_name, s.recruit, s.recruit_blocker(), true)
		Settler.Mode.WORKER:
			_line.text = s.character_class.role_summary if s.character_class else ""
			_add("Join my party", s.join_party, s.party_blocker())
			for job: JobDefinition in _jobs():
				var current := s.worker.job == job
				_add(("✓ " if current else "") + "Work as %s" % job.display_name,
					s.set_job.bind(job), "current job" if current else "", true)
		Settler.Mode.COMPANION:
			var holding := s.companion.order == CompanionController.Order.HOLD
			_line.text = s.character_class.role_summary if s.character_class else ""
			_add(("✓ " if not holding else "") + "Follow me", s.order_follow)
			_add("Hold this position", s.order_hold)
			_add("Go home and work (%s)" % s.job_title(), s.send_home)
	_add("Farewell", func(): pass)
	_render()


func _subtitle_text() -> String:
	var s := speaker
	match s.mode:
		Settler.Mode.WORKER:
			return "Settler · %s · %s" % [s.job_title(), s.worker.activity]
		Settler.Mode.COMPANION:
			return "Companion · %s" % s.companion.activity
	return "A stranger"


func _add(text: String, action: Callable, blocked := "", keep_open := false) -> void:
	_options.append({"text": text, "action": action, "blocked": blocked, "keep_open": keep_open})


func _jobs() -> Array:
	var jobs: Array = DataRegistry.get_all(JobDefinition)
	jobs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return jobs


func _render() -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in _options.size():
		var o := _options[i]
		var b := Button.new()
		b.text = "[%d]  %s%s" % [i + 1, o.text, "   — %s" % o.blocked if o.blocked != "" else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = o.blocked != ""
		b.add_theme_font_size_override(&"font_size", 17)
		b.pressed.connect(choose.bind(i))
		_list.add_child(b)


func _on_speaker_changed(_mode) -> void:
	_refresh.call_deferred()


func _refresh() -> void:
	if _open and is_instance_valid(speaker):
		_rebuild()


func _on_player_hurt(_event: DamageEvent) -> void:
	close()


func _disconnect() -> void:
	if is_instance_valid(speaker):
		speaker.mode_changed.disconnect(_on_speaker_changed)
		speaker.combat.died.disconnect(close)


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _set_player_input(on: bool) -> void:
	var p := _player()
	if p:
		p.controller.input_enabled = on


# --- layout ------------------------------------------------------------------------------

func _build() -> void:
	# Full-screen catcher: clicks around the panel don't reach the game.
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.position.y = -120  # clear of the controls help line
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.075, 0.06, 0.9)
	box.border_color = Color(0.55, 0.45, 0.3, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(16)
	_panel.add_theme_stylebox_override(&"panel", box)
	_blocker.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_panel.add_child(col)
	_title = _label(24, Color(0.98, 0.9, 0.7))
	col.add_child(_title)
	_subtitle = _label(14, Color(0.78, 0.75, 0.68))
	col.add_child(_subtitle)
	_line = _label(16, Color(0.93, 0.92, 0.86))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(528, 0)
	col.add_child(_line)
	col.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 4)
	col.add_child(_list)
	var hint := _label(13, Color(0.65, 0.63, 0.58))
	hint.text = "Press a number or click · E / Esc to leave"
	col.add_child(hint)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"outline_size", 4)
	return l
