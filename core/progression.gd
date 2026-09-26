extends Node
## What the player has unlocked through play (buildings today; recipes,
## spells and regions later). Dungeon rewards and quests call unlock();
## menus ask is_unlocked(). Persisted with the save.

var _unlocked: Dictionary = {}  # id -> true


func _ready() -> void:
	add_to_group(SaveManager.GROUP)


func unlock(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	EventBus.unlocked.emit(id)
	EventBus.unlocks_changed.emit()


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func reset() -> void:
	if _unlocked.is_empty():
		return
	_unlocked.clear()
	EventBus.unlocks_changed.emit()


func get_save_id() -> String:
	return "progression"


func save_state() -> Dictionary:
	return {"unlocked": _unlocked.keys().map(func(k): return String(k))}


func load_state(state: Dictionary) -> void:
	_unlocked.clear()
	for id in state.get("unlocked", []):
		_unlocked[StringName(id)] = true
	EventBus.unlocks_changed.emit()
