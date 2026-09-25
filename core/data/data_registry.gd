extends Node
## Indexes every GameData resource under res://data by id.
##
## Lets saves and gameplay code refer to content by stable id
## ("item.log") instead of by file path.

const DATA_ROOT := "res://data"

var _by_id: Dictionary = {}  # StringName -> GameData


func _ready() -> void:
	reload()


func reload() -> void:
	_by_id.clear()
	_scan(DATA_ROOT)


## Returns the definition with this id, or null (with an error) if unknown.
func get_data(id: StringName) -> GameData:
	var data: GameData = _by_id.get(id)
	if data == null:
		push_error("DataRegistry: unknown id '%s'" % id)
	return data


func has_data(id: StringName) -> bool:
	return _by_id.has(id)


## All definitions whose script is (or inherits) `type`, e.g. ItemData.
func get_all(type: Script) -> Array[GameData]:
	var result: Array[GameData] = []
	for data: GameData in _by_id.values():
		if _is_instance_of_script(data, type):
			result.append(data)
	return result


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(path.path_join(sub))
	for file in dir.get_files():
		# Exported builds list converted resources as "*.tres.remap".
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(path.path_join(file))
		if res is GameData:
			_register(res)


func _register(data: GameData) -> void:
	if data.id == &"":
		push_error("DataRegistry: %s has no id" % data.resource_path)
		return
	if _by_id.has(data.id):
		push_error("DataRegistry: duplicate id '%s' (%s and %s)" % [
			data.id, _by_id[data.id].resource_path, data.resource_path])
		return
	_by_id[data.id] = data


static func _is_instance_of_script(obj: Object, type: Script) -> bool:
	var s: Script = obj.get_script()
	while s != null:
		if s == type:
			return true
		s = s.get_base_script()
	return false
