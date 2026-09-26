class_name Chest
extends Node3D
## A treasure chest. Opening it swings the lid and pops its loot out as
## physical items (carried home like any other resource). Stays open
## across saves.

signal opened

@export var loot: Dictionary[StringName, int] = {}

@onready var interactable: Interactable = $Interactable
@onready var lid: Node3D = find_child("chest_lid", true, false)

var is_open := false


func _ready() -> void:
	add_to_group(SaveManager.GROUP)
	interactable.interacted.connect(func(_by): open())
	_update_prompt()


func open() -> void:
	if is_open:
		return
	is_open = true
	_set_lid(true, true)
	_spawn_loot()
	_update_prompt()
	opened.emit()


func _spawn_loot() -> void:
	var parent := get_tree().get_first_node_in_group(WorldItems.GROUP)
	if parent == null:
		parent = get_parent()
	var forward := global_basis.z.normalized()
	var i := 0
	for id in loot:
		var data := DataRegistry.get_data(id) as ItemData
		if data == null or data.carry_scene == null:
			continue
		for n in loot[id]:
			var body: Carryable = data.carry_scene.instantiate()
			parent.add_child(body)
			var side := forward.cross(Vector3.UP) * (float(i % 3) - 1.0) * 0.8
			body.global_position = global_position + forward * 1.4 + side + Vector3.UP * (0.9 + 0.3 * (i / 3))
			body.rotation.y = randf() * TAU
			body.apply_central_impulse((forward * 1.5 + Vector3.UP * 2.0) * body.mass * 0.5)
			i += 1


func _set_lid(open_lid: bool, animate: bool) -> void:
	if lid == null:
		return
	var target := Vector3(deg_to_rad(-105.0) if open_lid else 0.0, 0, 0)
	if animate:
		create_tween().tween_property(lid, "rotation", target, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation = target


func _update_prompt() -> void:
	interactable.prompt = "Empty chest" if is_open else "Open chest"
	interactable.enabled = not is_open


func get_save_id() -> String:
	return "chest:%s" % get_path()


func save_state() -> Dictionary:
	return {"open": is_open}


func load_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	_set_lid(is_open, false)
	_update_prompt()
