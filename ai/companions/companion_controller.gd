class_name CompanionController
extends Node
## Settler brain while adventuring with the player. Same body, same
## components as when working; the Settler switches brains. States
## (ai/companions/states/): Follow, Hold, Attack (incl. abilities), Retreat.
## Downed is not a state: the brain stops until revived (by the player's
## interact, or getting up by themselves after a while).

signal activity_changed(text: String)

enum Order { FOLLOW, HOLD }

## Threats this close to the player (or the hold point) get engaged.
const ENGAGE_RADIUS := 13.0
const HOLD_ENGAGE_RADIUS := 7.0
## Chasing never drags a companion further than this from the player.
const LEASH := 20.0
## Hopelessly far behind (e.g. fell off something): rejoin at the player.
const TELEPORT_DISTANCE := 45.0
const RETREAT_HEALTH := 0.3
const RECOVERED_HEALTH := 0.6
## Out of combat for this long: slowly recover health.
const REST_DELAY := 5.0
const REST_REGEN := 3.0
## A downed companion gets up by themselves after this long.
const DOWNED_SECONDS := 30.0
## Above RETREAT_HEALTH, so getting up doesn't mean standing there to be
## knocked down again.
const DOWNED_RECOVER_HEALTH := 0.4

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var abilities: AbilityController
@export var equipment: EquipmentController
@export var steering: NavSteering
@export var state_machine: StateMachine

var order := Order.FOLLOW
var hold_position := Vector3.ZERO
var target: CombatController
var activity := ""
var clock := 0.0

var _running := false
var _think_timer := 0.0
var _think_accum := 0.0
var _last_combat := -99.0
var _downed_serial := 0
## Someone who recently hurt the player or us: defended against first.
var _threat: CombatController
var _threat_until := 0.0


func _ready() -> void:
	process_physics_priority = -10
	set_physics_process(false)
	combat.aim_provider = func():
		return target.global_position() - body.global_position if _running and has_target() else Vector3.ZERO
	combat.aim_point_provider = func():
		return Targeting.aim_point(target) if _running and has_target() else null
	combat.receiver.damage_taken.connect(_on_damage_taken)
	combat.attack_started.connect(func(_a): _last_combat = clock)
	combat.died.connect(_on_died)
	combat.revived.connect(_on_revived)
	EventBus.damage_applied.connect(_on_any_damage)


func is_running() -> bool:
	return _running


func activate() -> void:
	_running = true
	set_physics_process(true)
	target = null
	if combat.is_alive() and state_machine.current == null:
		_start_brain()
	elif not combat.is_alive():
		set_activity("Downed")


func deactivate() -> void:
	_running = false
	set_physics_process(false)
	state_machine.stop()
	steering.stop()
	motor.set_facing_lock(&"ai", false)
	target = null
	set_activity("")


## `at`: where to hold (default: where we stand).
func set_order(new_order: Order, at: Variant = null) -> void:
	order = new_order
	if order == Order.HOLD:
		hold_position = at if at is Vector3 else body.global_position
	if _running and combat.is_alive():
		state_machine.transition_to(&"Hold" if order == Order.HOLD else &"Follow")


func set_activity(text: String) -> void:
	if text != activity:
		activity = text
		activity_changed.emit(text)


func _physics_process(delta: float) -> void:
	clock += delta
	if not combat.is_alive():
		return
	_rest(delta)
	_think_accum += delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = AiLod.think_interval(get_tree(), body.global_position)
		steering.refresh()
		state_machine.tick(_think_accum)
		_think_accum = 0.0


# --- queries for states ----------------------------------------------------------

func leader() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func distance_to_leader() -> float:
	var p := leader()
	return steering.distance_to(p.global_position) if p else 0.0


func formation_point() -> Vector3:
	var p := leader()
	if p == null:
		return body.global_position
	var party := Party.of(self)
	if party == null:
		return p.global_position
	return party.formation_point(body, p, p.motor.get_facing())


func has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_alive()


func distance_to_target() -> float:
	return steering.distance_to(target.global_position()) if has_target() else INF


## Who to fight: whoever is attacking the party, else the nearest enemy
## around the player (or around the hold point).
func pick_target() -> CombatController:
	var threat := current_threat()
	if threat:
		return threat
	var anchor := hold_position if order == Order.HOLD else _leader_position()
	var radius := HOLD_ENGAGE_RADIUS if order == Order.HOLD else ENGAGE_RADIUS
	# Only what we can actually see: no pulling the next room through a wall.
	return Targeting.nearest_visible_hostile(combat, radius, anchor)


## A living enemy that recently hurt the player or us, if still close
## enough to matter.
func current_threat() -> CombatController:
	if _threat == null or not is_instance_valid(_threat) or not _threat.is_alive() or clock >= _threat_until:
		return null
	var anchor := hold_position if order == Order.HOLD else _leader_position()
	var radius := HOLD_ENGAGE_RADIUS if order == Order.HOLD else ENGAGE_RADIUS
	if NavSteering.flat(_threat.global_position() - anchor).length() > radius * 1.5:
		return null
	return _threat


func is_ranged() -> bool:
	return equipment.weapon != null and equipment.weapon.aim_range > 6.0


## Furthest a ranged companion shoots from; melee reach otherwise.
func attack_reach() -> float:
	return minf(equipment.weapon.aim_range, 16.0) if is_ranged() else 1.7


func health_ratio() -> float:
	return combat.health.ratio()


## Hurt and in danger: time to fall back.
func should_retreat() -> bool:
	return health_ratio() < RETREAT_HEALTH and (current_threat() != null
		or Targeting.nearest_hostile_around(combat, body.global_position, 8.0) != null)


func in_combat() -> bool:
	return clock - _last_combat < REST_DELAY


func mark_combat() -> void:
	_last_combat = clock


## Uses the first ready ability whose range covers the target.
func try_ability() -> bool:
	if abilities == null or not has_target() or not combat.can_start_action():
		return false
	var d := distance_to_target()
	for i in abilities.abilities.size():
		var a := abilities.abilities[i]
		if abilities.is_ready(i) and d <= a.ai_use_range():
			motor.face(target.global_position() - body.global_position, true)
			return abilities.use(i)
	return false


func move_to(goal: Vector3, gait := CharacterMotor.Gait.RUN) -> void:
	steering.move_to(goal, gait)


func teleport_to_leader() -> void:
	var p := leader()
	if p == null:
		return
	var point := formation_point()
	var map := body.get_world_3d().navigation_map
	if NavSteering.is_map_ready(map):
		point = NavigationServer3D.map_get_closest_point(map, point)  # not inside a wall
	body.global_position = point + Vector3.UP * 0.1
	body.velocity = Vector3.ZERO
	steering.stop()


# --- internals ----------------------------------------------------------------------

func _leader_position() -> Vector3:
	var p := leader()
	return p.global_position if p else body.global_position


func _rest(delta: float) -> void:
	var health := combat.health
	if not in_combat() and health.current < health.max_health:
		health.heal(REST_REGEN * delta)


func _on_damage_taken(event: DamageEvent) -> void:
	_last_combat = clock
	var attacker := event.source_combatant
	if not _running or attacker == null or not combat.is_hostile_to(attacker):
		return
	_threat = attacker
	_threat_until = clock + 6.0


## Anyone hurting the player gets remembered as the party's threat.
func _on_any_damage(event: DamageEvent) -> void:
	if not _running or event.source_combatant == null:
		return
	var p := leader()
	if p and event.target == p and combat.is_hostile_to(event.source_combatant):
		_threat = event.source_combatant
		_threat_until = clock + 6.0


func _on_died() -> void:
	if not _running:
		return
	state_machine.stop()
	steering.stop()
	motor.set_facing_lock(&"ai", false)
	set_activity("Downed")
	_downed_serial += 1
	# Connected, not awaited: dropped automatically if we're freed (loading).
	get_tree().create_timer(DOWNED_SECONDS, false).timeout.connect(_recover.bind(_downed_serial))


func _recover(serial: int) -> void:
	if _running and not combat.is_alive() and serial == _downed_serial:
		combat.revive(combat.health.max_health * DOWNED_RECOVER_HEALTH)


func _on_revived() -> void:
	_last_combat = clock
	if _running and state_machine.current == null:
		_start_brain()


## Starts thinking in the state matching the current order.
func _start_brain() -> void:
	state_machine.start(self)
	if order == Order.HOLD:
		state_machine.transition_to(&"Hold")
