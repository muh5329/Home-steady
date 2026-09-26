class_name WorldItems
extends Node3D
## Container for loose physical items (logs on the ground, dropped crates).
## Persists them as {item_id, transform} and recreates them from ItemData
## on load, so saves never contain node trees.

const GROUP := &"props_root"


var _check := 1.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)


## Nothing is ever lost to the void: items that fall out of the world
## come back at the player's feet.
func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for c in get_children():
		var item := c as Carryable
		if item and item.global_position.y < Carryable.KILL_Y and item.carrier == null and player:
			item.linear_velocity = Vector3.ZERO
			item.global_position = player.global_position + Vector3(0, 1.5, 0) + NavSteering.flat(player.global_basis.z) * -1.2


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
