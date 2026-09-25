class_name InventoryComponent
extends Node
## Counts of items by id with a total capacity. Pure data holder; the
## owner (stockpile, warehouse, cart) decides how items get in and out.

signal changed(item_id: StringName, count: int)

@export var capacity := 40

var _counts: Dictionary = {}  # StringName -> int


func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func total() -> int:
	var t := 0
	for c: int in _counts.values():
		t += c
	return t


func free_space() -> int:
	return capacity - total()


func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _counts:
		if _counts[id] > 0:
			ids.append(id)
	return ids


func add(item_id: StringName, amount := 1) -> int:
	var added := mini(amount, free_space())
	if added <= 0:
		return 0
	_counts[item_id] = count(item_id) + added
	changed.emit(item_id, _counts[item_id])
	return added


func remove(item_id: StringName, amount := 1) -> int:
	var removed := mini(amount, count(item_id))
	if removed <= 0:
		return 0
	_counts[item_id] = count(item_id) - removed
	if _counts[item_id] == 0:
		_counts.erase(item_id)
	changed.emit(item_id, count(item_id))
	return removed


func to_dict() -> Dictionary:
	var d := {}
	for id: StringName in _counts:
		d[String(id)] = _counts[id]
	return d


func from_dict(d: Dictionary) -> void:
	var old_ids := _counts.keys()
	_counts.clear()
	for id in d:
		_counts[StringName(id)] = int(d[id])
	for id in old_ids:
		if not _counts.has(id):
			changed.emit(id, 0)
	for id: StringName in _counts:
		changed.emit(id, _counts[id])
