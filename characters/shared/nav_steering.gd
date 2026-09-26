class_name NavSteering
extends Node
## Walks a character along navigation paths via its CharacterMotor, with
## light separation from nearby allies. Shared by monsters and settlers.
## The owner calls refresh() at its think rate; steering runs every frame.

const SEPARATION_RADIUS := 1.6

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var agent: NavigationAgent3D
## Allies to keep apart from (same faction combatants).
@export var combat: CombatController
@export var arrive_distance := 0.4

var _goal = null  # Vector3 or null
var _gait := CharacterMotor.Gait.RUN
var _nav_ready := false
var _last_goal := Vector3.INF
var _separation := Vector3.ZERO


func _ready() -> void:
	process_physics_priority = -5  # after brains, before the motor


func move_to(goal: Vector3, gait := CharacterMotor.Gait.RUN) -> void:
	_goal = goal
	_gait = gait
	# Only repath when the goal moved meaningfully.
	if agent and goal.distance_squared_to(_last_goal) > 1.0:
		_last_goal = goal
		agent.target_position = goal


## Direct movement without pathfinding (strafing, short hops).
func move_direction(direction: Vector3, gait := CharacterMotor.Gait.WALK) -> void:
	_goal = null
	motor.set_move_input((direction + _separation).limit_length(1.0), gait)


func stop() -> void:
	_goal = null
	motor.stop()


func is_moving() -> bool:
	return _goal != null


func distance_to(point: Vector3) -> float:
	return flat(point - body.global_position).length()


## Cheap per-think updates: navigation readiness and crowd separation.
func refresh() -> void:
	_nav_ready = agent != null and is_map_ready(agent.get_navigation_map())
	_separation = _compute_separation()


## Map readiness cached per frame (shared by every agent on the map).
static var _ready_cache: Dictionary = {}  # RID -> [frame, bool]

static func is_map_ready(map: RID) -> bool:
	var frame := Engine.get_physics_frames()
	var cached: Array = _ready_cache.get(map, [-1, false])
	if cached[0] != frame:
		cached = [frame, NavigationServer3D.map_get_iteration_id(map) > 0
			and not NavigationServer3D.map_get_regions(map).is_empty()]
		_ready_cache[map] = cached
	return cached[1]


func _physics_process(_delta: float) -> void:
	if _goal == null:
		return
	var goal: Vector3 = _goal
	if distance_to(goal) < arrive_distance:
		motor.stop()
		return
	var next := goal
	if _nav_ready:
		next = agent.get_next_path_position()
	var dir := flat(next - body.global_position)
	if dir.length_squared() < 0.0001:
		dir = flat(goal - body.global_position)
	motor.set_move_input((dir.normalized() + _separation).normalized(), _gait)


func _compute_separation() -> Vector3:
	if combat == null:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == combat or other.faction != combat.faction or not other.is_alive():
			continue
		var away := flat(body.global_position - other.global_position())
		var d := away.length()
		if d < SEPARATION_RADIUS and d > 0.001:
			push += away / d * (1.0 - d / SEPARATION_RADIUS)
	return push.limit_length(0.8)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
