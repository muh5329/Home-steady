class_name BossPresence
extends Node
## Added to bosses: tells the HUD (via EventBus) when the fight with the
## player starts and ends. "Engaged" means it is fighting and the player
## is actually there — not companions left behind in a crypt.

const PLAYER_RANGE := 35.0

var enemy: Enemy
var _engaged := false
var _check := 0.0


func _ready() -> void:
	enemy.combat.died.connect(func(): _set_engaged(false))


func _exit_tree() -> void:
	_set_engaged(false)


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	var engaged := enemy.combat.is_alive() and enemy.controller.has_valid_target() \
		and player != null and player.combat.is_alive() \
		and player.global_position.distance_to(enemy.global_position) < PLAYER_RANGE
	_set_engaged(engaged)


func _set_engaged(value: bool) -> void:
	if value == _engaged:
		return
	_engaged = value
	if value:
		EventBus.boss_engaged.emit(enemy)
	else:
		EventBus.boss_disengaged.emit(enemy)
