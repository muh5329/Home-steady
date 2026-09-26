class_name Population
extends Node3D
## Container for the settlement's people (settlers, companions and the
## strangers met nearby). Settlers are runtime entities
## (recruited, rescued), so this registry persists them as data and
## recreates them on load.

const SETTLER_SCENE := preload("res://characters/npc/settler.tscn")

var _next_uid := 1


func _ready() -> void:
	add_to_group(SaveManager.GROUP)
	# Settlers placed in the editor get uids too.
	for c in get_children():
		if c is Settler and c.uid == "":
			c.uid = _new_uid()


func settlers() -> Array[Settler]:
	var out: Array[Settler] = []
	for c in get_children():
		if c is Settler and not c.is_queued_for_deletion():
			out.append(c)
	return out


func spawn_settler(at: Vector3, settler_name: String, uid := "", job: JobDefinition = null,
		character_class: CharacterClassData = null, mode := Settler.Mode.WORKER) -> Settler:
	var s: Settler = SETTLER_SCENE.instantiate()
	s.settler_name = settler_name
	s.mode = mode
	if character_class:
		s.character_class = character_class
	if job:
		s.get_node("Worker").job = job
	s.uid = uid if uid != "" else _new_uid()
	s.name = "Settler_" + s.uid
	s.position = at
	add_child(s)
	return s


func _new_uid() -> String:
	var uid := "s%d" % _next_uid
	_next_uid += 1
	return uid


func get_save_id() -> String:
	return "population:%s" % get_path()


func save_state() -> Dictionary:
	var entries := []
	for s in settlers():
		entries.append({"uid": s.uid, "state": s.save_state()})
	return {"next_uid": _next_uid, "settlers": entries}


func load_state(state: Dictionary) -> void:
	for s in settlers():
		s.carry.discard_carried()
		remove_child(s)
		s.queue_free()
	_next_uid = int(state.get("next_uid", 1))
	for e in state.get("settlers", []):
		var st: Dictionary = e["state"]
		var s := spawn_settler(SaveManager.array_to_vec3(st["origin"]), st.get("name", "Settler"), e["uid"])
		s.load_state(st)
