extends Node
## Owns session-level state: world seed, elapsed play time, pause, and the
## quick save/load hotkeys. Deliberately small; gameplay systems live in
## their own nodes.

var world_seed: int = 0
## Chosen at the class select screen; the Player builds itself from it.
var selected_class: CharacterClassData
var play_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(SaveManager.GROUP)
	if world_seed == 0:
		world_seed = randi()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		var err := SaveManager.save_game()
		if err == ERR_BUSY:
			DebugOverlay.notify("Can't save right now")
		else:
			DebugOverlay.notify("Saved" if err == OK else "Save failed (%s)" % error_string(err))
	elif event.is_action_pressed(&"quick_load"):
		var err := SaveManager.load_game()
		DebugOverlay.notify("Loaded" if err == OK else "Load failed (%s)" % error_string(err))
	elif event.is_action_pressed(&"pause"):
		set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


# --- persistence ----------------------------------------------------------

func get_save_id() -> String:
	return "game"


func save_state() -> Dictionary:
	return {"world_seed": world_seed, "play_time": play_time,
		"class": String(selected_class.id) if selected_class else ""}


func load_state(state: Dictionary) -> void:
	world_seed = int(state.get("world_seed", world_seed))
	play_time = float(state.get("play_time", 0.0))
	var class_id := StringName(state.get("class", ""))
	if class_id != &"" and DataRegistry.has_data(class_id):
		selected_class = DataRegistry.get_data(class_id) as CharacterClassData
