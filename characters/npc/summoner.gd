class_name Summoner
extends Node
## Raises monsters for summon abilities: an armored cast (flinches don't
## stop it, a poise break does), then the summons climb out around the
## caster. Tracks them: they crumble when the caster dies and vanish when
## it leaves or resets (a load), so no orphaned minions pile up.

@export var combat: CombatController

var _summoned: Array[Enemy] = []


func _ready() -> void:
	combat.died.connect(dismiss_all)


## The caster left (a load reset it, the area unloaded): its summons go
## quietly with it.
func _exit_tree() -> void:
	for s in _summoned:
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			s.queue_free()
	_summoned.clear()


func alive() -> int:
	_summoned = _summoned.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.combat.is_alive())
	return _summoned.size()


func can_raise(a: AbilityData) -> bool:
	return alive() < a.summon_max_alive


## Starts the cast. `on_cancel` runs if it gets interrupted.
func cast(a: AbilityData, on_cancel: Callable) -> bool:
	if not combat.perform(a.summon_animation, 1.0, 0.0, -1.0, true):
		return false
	get_tree().create_timer(a.summon_delay, false).timeout.connect(
		_raise.bind(a, combat.action_serial, on_cancel))
	return true


func _raise(a: AbilityData, serial: int, on_cancel: Callable) -> void:
	if combat.action_serial != serial or not combat.is_alive():
		on_cancel.call()
		return
	var body := combat.body
	var map := body.get_world_3d().navigation_map
	var n := mini(a.summon_count, a.summon_max_alive - alive())
	for i in n:
		var angle := TAU * float(i) / maxf(n, 1) + randf() * 0.5
		var at := body.global_position + Vector3(cos(angle), 0, sin(angle)) * a.summon_radius
		if NavSteering.is_map_ready(map):
			at = NavigationServer3D.map_get_closest_point(map, at)
		_summoned.append(Enemy.raise(a.summon, body.get_parent(), at))


func dismiss_all() -> void:
	for s in _summoned:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and s.combat.is_alive():
			s.health.take(s.health.current)
	_summoned.clear()
