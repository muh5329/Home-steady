class_name WorldItems
extends Node3D
## Container for loose physical items (logs on the ground, dropped crates).
## Persists them as {item_id, transform} and recreates them from ItemData
## on load, so saves never contain node trees.

const GROUP := &"props_root"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)


func get_save_id() -> String:
	return "world_items:%s" % get_path()


func save_state() -> Dictionary:
	var items := []
	for child in get_children():
		var c := child as Carryable
		if c == null or c.item_id == &"" or c.is_queued_for_deletion():
			continue
		var t := c.global_transform
		items.append({
			"id": String(c.item_id),
			"origin": SaveManager.vec3_to_array(t.origin),
			"rot": SaveManager.vec3_to_array(t.basis.get_euler()),
		})
	return {"items": items}


func load_state(state: Dictionary) -> void:
	for child in get_children():
		if child is Carryable:
			remove_child(child)
			child.queue_free()
	for entry in state.get("items", []):
		var data := DataRegistry.get_data(StringName(entry["id"])) as ItemData
		if data == null or data.carry_scene == null:
			continue
		var body: Carryable = data.carry_scene.instantiate()
		add_child(body)
		body.global_position = SaveManager.array_to_vec3(entry["origin"])
		body.rotation = SaveManager.array_to_vec3(entry["rot"])
