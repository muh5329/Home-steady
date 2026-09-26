class_name EnemyController
extends Node
## Shared monster brain. Owns perception, navigation steering and the AI
## state machine; the states (ai/states/) decide *what* to do and call the
## helpers here. Thinking is throttled by distance to the player.

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var steering: NavSteering
@export var state_machine: StateMachine

var definition: EnemyDefinition
var home_position: Vector3
var target: CombatController

var _think_timer := 0.0
var _think_accum := 0.0
var _home_set := false
var _provoked := 0.0


func _ready() -> void:
	process_physics_priority = -10  # decide before combat/motor run
	combat.aim_provider = _aim_direction
	combat.aim_point_provider = func(): return Targeting.aim_point(target) if has_valid_target() else null
	combat.died.connect(func(): motor.stop())
	combat.receiver.damage_taken.connect(_on_damage_taken)
	# Stagger think timers so a crowd doesn't think on the same frame.
	_think_timer = randf() * 0.1
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	if not combat.is_alive():
		return
	if not _home_set:
		# Deferred to the first frame so spawners can position us first.
		_home_set = true
		home_position = body.global_position
	_think_accum += delta
	_think_timer -= delta
	_provoked = maxf(_provoked - delta, 0.0)
	if _think_timer <= 0.0:
		_think_timer = AiLod.think_interval(get_tree(), body.global_position)
		steering.refresh()
		state_machine.tick(_think_accum)
		_think_accum = 0.0


# --- helpers for states ---------------------------------------------------------

func find_target() -> CombatController:
	return combat.find_nearest_hostile(definition.aggro_range)


func has_valid_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_alive()


func distance_to_target() -> float:
	if not has_valid_target():
		return INF
	return _flat(target.global_position() - body.global_position).length()


func is_provoked() -> bool:
	return _provoked > 0.0


func distance_from_home() -> float:
	return _flat(home_position - body.global_position).length()


func move_to(goal: Vector3, gait := CharacterMotor.Gait.RUN) -> void:
	steering.move_to(goal, gait)


func stop_moving() -> void:
	steering.stop()


func face_target() -> void:
	if has_valid_target():
		motor.face(target.global_position() - body.global_position)


## Direct movement without pathfinding (strafing, short hops).
func move_direction(direction: Vector3, gait := CharacterMotor.Gait.WALK) -> void:
	steering.move_direction(direction, gait)


# --- internals ------------------------------------------------------------------

## Being hit always pulls aggro onto the attacker.
func _on_damage_taken(event: DamageEvent) -> void:
	var attacker := event.source_combatant
	if attacker == null or not combat.is_alive() or not combat.is_hostile_to(attacker):
		return
	target = attacker
	_provoked = definition.provoked_seconds
	if state_machine.current_name() in [&"Idle", &"Return"]:
		state_machine.transition_to(&"Chase")




func _aim_direction() -> Vector3:
	if has_valid_target():
		return target.global_position() - body.global_position
	return Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return NavSteering.flat(v)
