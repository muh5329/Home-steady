extends Node
## Persists game state as plain data (ids + values), never as node trees.
##
## Any node that wants to be saved joins the "persistent" group and
## implements:
##     func get_save_id() -> String        # stable, unique per node
##     func save_state() -> Dictionary     # JSON-safe values only
##     func load_state(state: Dictionary) -> void
##
## Optionally `func can_save() -> bool` vetoes saving (e.g. while dead).
##
## Nodes that are created at runtime (dropped logs, placed buildings) are
## restored by whichever system spawned them; that system is itself a
## persistent node that saves the list of what it spawned.

const GROUP := &"persistent"
const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 1


func save_game(slot: String = "quick") -> Error:
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method("can_save") and not node.can_save():
			return ERR_BUSY
	var entities := {}
	for node in get_tree().get_nodes_in_group(GROUP):
		if not _is_persistable(node):
			push_warning("SaveManager: %s is in '%s' but lacks the save API" % [node.get_path(), GROUP])
			continue
		var id: String = node.get_save_id()
		if entities.has(id):
			push_error("SaveManager: duplicate save id '%s'" % id)
			continue
		entities[id] = node.save_state()

	var payload := {
		"version": FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"entities": entities,
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.game_saved.emit(slot)
	return OK


func load_game(slot: String = "quick") -> Error:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("entities"):
		push_error("SaveManager: corrupt save '%s'" % path)
		return ERR_FILE_CORRUPT
	var entities: Dictionary = parsed["entities"]
	for node in get_tree().get_nodes_in_group(GROUP):
		if not _is_persistable(node):
			continue
		var id: String = node.get_save_id()
		if entities.has(id):
			node.load_state(entities[id])
	EventBus.game_loaded.emit(slot)
	return OK


func has_save(slot: String = "quick") -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String = "quick") -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join("%s.json" % slot)


static func _is_persistable(node: Node) -> bool:
	return node.has_method("get_save_id") and node.has_method("save_state") \
		and node.has_method("load_state")


# --- JSON helpers for common engine types --------------------------------

static func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
