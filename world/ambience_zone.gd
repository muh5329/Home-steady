class_name AmbienceZone
extends Area3D
## While the player is inside, the region's WorldEnvironment uses this
## zone's Environment and the sun can be switched off (crypts, caves).
## Leaving (walking out, travelling, respawning) restores the outdoors.

@export var environment: Environment
@export var sun_enabled := false
## Highest camera pitch while inside (negative = looking down); INF = no limit.
@export var camera_max_pitch := INF

var _saved: Environment
var _inside := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # characters
	monitoring = true
	monitorable = false
	body_entered.connect(func(b): if b is Player: _apply(b))
	body_exited.connect(func(b): if b is Player: _restore(b))


func is_active() -> bool:
	return _inside


func _apply(player: Player) -> void:
	if _inside:
		return
	player.camera_rig.max_pitch_override = camera_max_pitch
	var world_env := _world_environment()
	if world_env:
		_saved = world_env.environment
		world_env.environment = environment
	for sun in _suns():
		sun.visible = sun_enabled
	_inside = true


func _restore(player: Player) -> void:
	if not _inside:
		return
	player.camera_rig.max_pitch_override = INF
	var world_env := _world_environment()
	if world_env and _saved:
		world_env.environment = _saved
	for sun in _suns():
		sun.visible = true
	_inside = false


func _region() -> Node:
	var n := get_parent()
	while n and not n is Region:
		n = n.get_parent()
	return n


func _world_environment() -> WorldEnvironment:
	var r := _region()
	return r.find_child("WorldEnvironment", false, false) as WorldEnvironment if r else null


func _suns() -> Array[DirectionalLight3D]:
	var out: Array[DirectionalLight3D] = []
	var r := _region()
	if r:
		for c in r.get_children():
			if c is DirectionalLight3D:
				out.append(c)
	return out
