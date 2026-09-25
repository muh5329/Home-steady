class_name EnemyController
extends Node
## Shared monster brain. Owns perception, navigation steering and the AI
## state machine; the states (ai/states/) decide *what* to do and call the
## helpers here. Thinking is throttled by distance to the player.

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var agent: NavigationAgent3D
@export var state_machine: StateMachine

var definition: EnemyDefinition
var home_position: Vector3
var target: CombatController

var _move_goal = null  # Vector3 or null
var _gait := CharacterMotor.Gait.RUN
var _think_timer := 0.0
var _think_accum := 0.0
var _home_set := false
var _provoked := 0.0
var _nav_ready := false
var _last_goal := Vector3.INF
## Push away from nearby allies, refreshed at think rate (cheap crowds).
var _separation := Vector3.ZERO
const SEPARATION_RADIUS := 1.6


func _ready() -> void:
	process_physics_priority = -10  # decide before combat/motor run
	combat.aim_provider = _aim_direction
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
		_think_timer = _think_interval()
		_nav_ready = agent != null and _navigation_ready()
		state_machine.tick(_think_accum)
		_think_accum = 0.0
		_separation = _compute_separation()
	_steer()


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
	_move_goal = goal
	_gait = gait
	# Only repath when the goal moved meaningfully.
	if agent and goal.distance_squared_to(_last_goal) > 1.0:
		_last_goal = goal
		agent.target_position = goal


func stop_moving() -> void:
	_move_goal = null
	motor.stop()


func face_target() -> void:
	if has_valid_target():
		motor.face(target.global_position() - body.global_position)


## Direct movement without pathfinding (strafing, short hops).
func move_direction(direction: Vector3, gait := CharacterMotor.Gait.WALK) -> void:
	_move_goal = null
	motor.set_move_input((direction + _separation).limit_length(1.0), gait)


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


func _steer() -> void:
	if _move_goal == null:
		return
	var goal: Vector3 = _move_goal
	var next := goal
	if _nav_ready:
		next = agent.get_next_path_position()
	var dir := _flat(next - body.global_position)
	if _flat(goal - body.global_position).length() < 0.4:
		motor.stop()
		return
	motor.set_move_input((dir.normalized() + _separation).normalized(), _gait)


func _compute_separation() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == combat or other.faction != combat.faction or not other.is_alive():
			continue
		var away := _flat(body.global_position - other.global_position())
		var d := away.length()
		if d < SEPARATION_RADIUS and d > 0.001:
			push += away / d * (1.0 - d / SEPARATION_RADIUS)
	return push.limit_length(0.8)


func _navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0 \
		and not NavigationServer3D.map_get_regions(agent.get_navigation_map()).is_empty()


func _think_interval() -> float:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return 0.5
	var d := body.global_position.distance_to(player.global_position)
	if d < 25.0:
		return 0.1
	if d < 60.0:
		return 0.35
	return 1.0


func _aim_direction() -> Vector3:
	if has_valid_target():
		return target.global_position() - body.global_position
	return Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
