class_name WorkerController
extends Node
## Settler brain for settlement work. Every job runs the same StateMachine
## (ai/jobs/states/): Idle -> GoToWork -> Work -> Collect -> Deliver.
## The JobDefinition supplies everything job-specific; this node offers
## shared helpers (movement, progress/stuck tracking, threat memory,
## settlement queries, tool swings) and throttles *decisions* by distance.
## Work swings themselves run at full speed regardless of distance.

signal activity_changed(text: String)
signal job_changed(job: JobDefinition)

## Seconds a downed settler lies before getting back up at home.
const DOWNED_SECONDS := 20.0
## Unreachable targets are ignored for this long.
const BLACKLIST_SECONDS := 60.0
## Work near a recent attack is avoided for this long / within this radius.
const THREAT_SECONDS := 25.0
const THREAT_RADIUS := 14.0
## An approach that hasn't closed 0.3 m in this long is considered stuck.
const STUCK_SECONDS := 4.0

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var carry: CarryComponent
@export var steering: NavSteering
@export var state_machine: StateMachine
@export var job: JobDefinition

var home_position: Vector3
## Where the last job happened (produce is collected around here).
var last_work_position: Vector3
var activity := "Idle"
## Game-time clock used for timers below.
var clock := 0.0

var _think_timer := 0.0
var _think_accum := 0.0
var _started := false
var _blacklist: Dictionary = {}  # Object -> expiry clock
var _threat_position := Vector3.INF
var _threat_until := 0.0
var _approach_goal := Vector3.INF
var _approach_best := INF
var _approach_since := 0.0


func _ready() -> void:
	process_physics_priority = -10
	combat.receiver.damage_taken.connect(_on_damage_taken)
	combat.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	clock += delta
	if not combat.is_alive():
		return
	if not _started:
		# First frame: spawners have positioned us by now.
		_started = true
		if home_position == Vector3.ZERO:
			home_position = body.global_position
		last_work_position = home_position
		state_machine.start(self)
	_think_accum += delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = AiLod.think_interval(get_tree(), body.global_position)
		steering.refresh()
		state_machine.tick(_think_accum)
		_think_accum = 0.0


func set_job(new_job: JobDefinition) -> void:
	if new_job == job:
		return
	job = new_job
	job_changed.emit(job)
	if _started and combat.is_alive():
		state_machine.transition_to(&"Idle")


func set_activity(text: String) -> void:
	if text != activity:
		activity = text
		activity_changed.emit(text)


func settlement() -> Settlement:
	return Settlement.of(self)


func is_near(point: Vector3, distance: float) -> bool:
	return steering.distance_to(point) <= distance


# --- approach / stuck detection ------------------------------------------------

## Moves toward `goal`; a new goal resets the progress watchdog.
func approach(goal: Vector3, gait := CharacterMotor.Gait.RUN) -> void:
	_track(goal)
	steering.move_to(goal, gait)


## True if approaching `goal` made no progress for STUCK_SECONDS.
func is_stuck(goal: Vector3) -> bool:
	_track(goal)
	var d := steering.distance_to(goal)
	if d < _approach_best - 0.3:
		_approach_best = d
		_approach_since = clock
	return clock - _approach_since > STUCK_SECONDS


func _track(goal: Vector3) -> void:
	if goal.distance_squared_to(_approach_goal) > 0.25:
		_approach_goal = goal
		_approach_best = steering.distance_to(goal)
		_approach_since = clock


func blacklist(target: Object) -> void:
	_blacklist[target] = clock + BLACKLIST_SECONDS


func is_blacklisted(target: Object) -> bool:
	return _blacklist.has(target) and _blacklist[target] > clock


# --- threats ---------------------------------------------------------------------

func is_threatened_at(point: Vector3) -> bool:
	return clock < _threat_until and point.distance_to(_threat_position) < THREAT_RADIUS


## Filter for settlement searches: skip blacklisted or dangerous targets.
func should_skip(target: Node3D) -> bool:
	return is_blacklisted(target) or is_threatened_at(target.global_position)


# --- work --------------------------------------------------------------------------

## One tool swing: plays the job's clip and applies its work to `target`
## at the impact frame. Returns the target's apply_work() result, or null
## if the swing couldn't start or was interrupted.
func swing_at(target: Node3D) -> Variant:
	motor.face(target.global_position - body.global_position, true)
	# Capture everything before awaiting: the job may change meanwhile.
	var amount := job.work_amount
	var tags := job.work_tags.duplicate()
	tags.append("work")
	var impact := job.work_impact_time / job.work_speed
	if not combat.perform(job.work_animation, job.work_speed):
		return null
	var serial := combat.action_serial
	await get_tree().create_timer(impact, false, true).timeout
	if combat.action_serial != serial or not is_instance_valid(target):
		return null  # interrupted: hit, fled, died, or another action
	return target.apply_work(amount, body, tags)


func _on_damage_taken(event: DamageEvent) -> void:
	var attacker := event.source_combatant
	if attacker == null or not combat.is_hostile_to(attacker) or not combat.is_alive():
		return
	_threat_position = attacker.global_position()
	_threat_until = clock + THREAT_SECONDS
	if state_machine.current:
		state_machine.transition_to(&"Flee", {"from": _threat_position})


## Downed: drop everything, lie there, then get up at home.
func _on_died() -> void:
	steering.stop()
	state_machine.stop()  # exits the state: releases claims
	set_activity("Downed")
	await get_tree().create_timer(DOWNED_SECONDS, false).timeout
	if not is_instance_valid(body):
		return
	body.global_position = home_position
	body.velocity = Vector3.ZERO
	combat.revive(combat.health.max_health * 0.5)
	state_machine.start(self)
