class_name AbilityController
extends Node
## Owns a character's abilities and their cooldowns; using one asks the
## CombatController to perform its attack, or hands a summon to the
## character's Summoner (if it has one).

signal ability_used(index: int, ability: AbilityData)
signal abilities_changed

@export var combat: CombatController
## Optional: characters that can raise others (necromancers).
@export var summoner: Summoner

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
	if index >= abilities.size() or _cooldowns[index] > 0.0:
		return false
	var a := abilities[index]
	if combat.health and combat.health.ratio() > a.use_below_health:
		return false
	if a.summon:
		return summoner != null and summoner.can_raise(a)
	return true


func summons_alive() -> int:
	return summoner.alive() if summoner else 0


## Queues the ability. Its cooldown starts only when the attack actually
## starts, so a press that gets dropped or overridden costs nothing.
## Returns true if it was queued.
func use(index: int) -> bool:
	if not is_ready(index) or not combat.is_alive():
		return false
	var a := abilities[index]
	if a.summon:
		return _cast_summon(index, a)
	combat.request_special(a.attack)
	return true


func _cast_summon(index: int, a: AbilityData) -> bool:
	if not summoner.cast(a, _refund.bind(index)):
		return false
	_cooldowns[index] = a.cooldown
	ability_used.emit(index, a)
	return true


## A cast that got interrupted costs nothing.
func _refund(index: int) -> void:
	if index < _cooldowns.size():
		_cooldowns[index] = 0.0


func _on_attack_started(attack: AttackData) -> void:
	for i in abilities.size():
		if abilities[i].attack == attack:
			_cooldowns[i] = abilities[i].cooldown
			ability_used.emit(i, abilities[i])


func _physics_process(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
