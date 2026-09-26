class_name AbilityController
extends Node
## Owns a character's abilities and their cooldowns; using one asks the
## CombatController to perform its attack.

signal ability_used(index: int, ability: AbilityData)
signal abilities_changed

@export var combat: CombatController

var abilities: Array[AbilityData] = []
var _cooldowns: Array[float] = []


func _ready() -> void:
	combat.attack_started.connect(_on_attack_started)


func set_abilities(list: Array[AbilityData]) -> void:
	abilities = list
	_cooldowns.resize(list.size())
	_cooldowns.fill(0.0)
	abilities_changed.emit()


func cooldown_left(index: int) -> float:
	return _cooldowns[index] if index < _cooldowns.size() else 0.0


func is_ready(index: int) -> bool:
	return index < abilities.size() and _cooldowns[index] <= 0.0


## Queues the ability. Its cooldown starts only when the attack actually
## starts, so a press that gets dropped or overridden costs nothing.
## Returns true if it was queued.
func use(index: int) -> bool:
	if not is_ready(index) or not combat.is_alive():
		return false
	combat.request_special(abilities[index].attack)
	return true


func _on_attack_started(attack: AttackData) -> void:
	for i in abilities.size():
		if abilities[i].attack == attack:
			_cooldowns[i] = abilities[i].cooldown
			ability_used.emit(i, abilities[i])


func _physics_process(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
