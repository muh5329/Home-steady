class_name Region
extends Node3D
## A playable area: bakes navigation at load, owns the player spawn point
## and respawns the player after death.

@export var player: Player
@export var spawn_point: Marker3D
@export var navigation_region: NavigationRegion3D
@export var respawn_delay := 3.5


func _ready() -> void:
	if navigation_region:
		navigation_region.bake_navigation_mesh(false)
	if player:
		if spawn_point:
			player.global_position = spawn_point.global_position
		player.combat.died.connect(_on_player_died)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_player_died() -> void:
	await get_tree().create_timer(respawn_delay, false).timeout
	player.respawn(spawn_point.global_position if spawn_point else Vector3.ZERO)
