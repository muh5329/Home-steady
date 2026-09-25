class_name Region
extends Node3D
## A playable area: bakes navigation at load, owns the player spawn point
## and respawns the player after death.

@export var player: Player
@export var spawn_point: Marker3D
@export var navigation_region: NavigationRegion3D
@export var respawn_delay := 3.5


var _rebake_pending := false


func _ready() -> void:
	if navigation_region:
		navigation_region.bake_navigation_mesh(false)
		EventBus.world_geometry_changed.connect(_queue_rebake)
	if player:
		if spawn_point:
			player.global_position = spawn_point.global_position
		player.combat.died.connect(_on_player_died)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Debounced async navmesh rebake after buildings appear/change.
func _queue_rebake() -> void:
	if _rebake_pending or navigation_region == null:
		return
	_rebake_pending = true
	await get_tree().create_timer(0.5).timeout
	_rebake_pending = false
	if not is_instance_valid(navigation_region):
		return
	if navigation_region.is_baking():
		navigation_region.bake_finished.connect(_queue_rebake, CONNECT_ONE_SHOT)
	else:
		navigation_region.bake_navigation_mesh(true)


func _on_player_died() -> void:
	await get_tree().create_timer(respawn_delay, false).timeout
	player.respawn(spawn_point.global_position if spawn_point else Vector3.ZERO)
