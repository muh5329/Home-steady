class_name CryptGate
extends Node3D
## A locked door that opens when the right key is handed to it (carry the
## key up and press E, like delivering to a stockpile). Opening swings the
## door, clears its collider and rebakes the dungeon's navigation.
## Stays open across saves. If the key's keeper is dead and the key is
## nowhere to be found (lost, or an older save), a new one turns up here:
## progress can never be locked away.

signal opened

@export var key_item: StringName = &"item.crypt_key"

@onready var interactable: Interactable = $Interactable
@onready var door: Node3D = find_child("wall_doorway_door", true, false)
@onready var blocker: CollisionShape3D = $Body/Door

var is_open := false
var _recover_check := 2.0


func _ready() -> void:
	add_to_group(SaveManager.GROUP)
	interactable.deposit_verb = "Unlock with"
	interactable.item_filter = func(item: Carryable) -> bool:
		return not is_open and item.item_id == key_item
	interactable.item_receiver = func(item: Carryable) -> bool:
		item.queue_free()
		open()
		return true
	interactable.interacted.connect(func(_by):
		if not is_open:
			DebugOverlay.notify("Locked. The champion of this crypt carries the key."))
	_update()


func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	_update(animate)
	opened.emit()


func _update(animate := false) -> void:
	interactable.prompt = "Locked door" if not is_open else ""
	interactable.enabled = not is_open
	var changed := blocker.disabled != is_open
	blocker.set_deferred(&"disabled", is_open)
	if door:
		var target := Vector3(0, deg_to_rad(-100.0) if is_open else 0.0, 0)
		if animate:
			create_tween().tween_property(door, "rotation", target, 1.2).set_trans(Tween.TRANS_SINE)
		else:
			door.rotation = target
	if changed:
		NavRebake.queue(NavRebake.region_of(self))


func _physics_process(delta: float) -> void:
	if is_open:
		return
	_recover_check -= delta
	if _recover_check > 0.0:
		return
	_recover_check = 2.0
	if _key_keeper_defeated() and not _key_exists():
		var drop := LootDrop.spill(get_tree(), {key_item: 1}, global_position, global_basis.z)
		if not drop.is_empty():
			DebugOverlay.notify("A key glints in the dust by the door.")


func _key_keeper_defeated() -> bool:
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if sp.definition.loot.has(key_item) and sp.is_defeated:
			return true
	return false


func _key_exists() -> bool:
	for c in get_tree().get_nodes_in_group(Carryable.GROUP):
		if c.item_id == key_item and not c.is_queued_for_deletion():
			return true
	return false


func get_save_id() -> String:
	return "gate:%s" % get_path()


func save_state() -> Dictionary:
	return {"open": is_open}


func load_state(state: Dictionary) -> void:
	var was := is_open
	is_open = state.get("open", false)
	if was != is_open:
		_update()
