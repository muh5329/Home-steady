class_name CharacterMotor
extends Node
## Moves a CharacterBody3D. Brains (player input or AI) only tell it where
## they *want* to go; the motor owns velocity, gravity, turning, jumping,
## short scripted bursts (dodges, lunges) and knockback.

signal jumped
signal landed

enum Gait { WALK, RUN, SPRINT }

@export var body: CharacterBody3D
@export var walk_speed := 2.2
@export var run_speed := 5.0
@export var sprint_speed := 7.6
@export var acceleration := 40.0
@export var deceleration := 50.0
@export var air_control := 0.3
## Radians per second.
@export var turn_speed := 14.0
@export var jump_velocity := 5.6
## Extra gravity when falling makes jumps feel snappy instead of floaty.
@export var fall_gravity_multiplier := 1.6

## Multiplies turn speed (0 = facing locked, e.g. mid-swing).
var turn_multiplier := 1.0
## True while any system holds a facing lock: movement input no longer
## turns the body (blocking, aiming, circling). Facing then comes only
## from face(). Locks are named so systems never clear each other's.
var lock_facing: bool:
	get: return not _facing_locks.is_empty()
var _facing_locks: Dictionary = {}  # StringName -> true


func set_facing_lock(key: StringName, locked: bool) -> void:
	if locked:
		_facing_locks[key] = true
	else:
		_facing_locks.erase(key)

## Named speed multipliers from independent systems (combat, carrying...).
## Effective multiplier is their product, so systems never overwrite
## each other.
var _speed_modifiers: Dictionary = {}  # StringName -> float

var _wish_dir := Vector3.ZERO
var _gait := Gait.RUN
var _facing := Vector3.FORWARD
var _burst_velocity := Vector3.ZERO
var _burst_time := 0.0
var _knockback := Vector3.ZERO
var _was_on_floor := true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_time := 0.0
var _jump_buffer := 0.0
var _hold := 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	_facing = -body.global_basis.z
	# Run after brains/combat so this frame's commands are applied.
	process_physics_priority = 10


## World-space horizontal direction the brain wants to move in (length <= 1).
func set_move_input(direction: Vector3, gait: Gait = Gait.RUN) -> void:
	direction.y = 0.0
	_wish_dir = direction.limit_length(1.0)
	_gait = gait


func set_speed_modifier(key: StringName, value: float) -> void:
	if is_equal_approx(value, 1.0):
		_speed_modifiers.erase(key)
	else:
		_speed_modifiers[key] = value


func speed_multiplier() -> float:
	var m := 1.0
	for v: float in _speed_modifiers.values():
		m *= v
	return m


func stop() -> void:
	_wish_dir = Vector3.ZERO


func request_jump() -> void:
	_jump_buffer = 0.15


## Moves at `velocity` for `duration` seconds, overriding normal movement.
func burst(velocity: Vector3, duration: float) -> void:
	velocity.y = 0.0
	_burst_velocity = velocity
	_burst_time = duration


## Freezes movement for a moment (hitstop). Velocity resumes afterwards.
func hold(duration: float) -> void:
	_hold = maxf(_hold, duration)


func cancel_burst() -> void:
	_burst_time = 0.0


func add_knockback(impulse: Vector3) -> void:
	impulse.y = 0.0
	_knockback += impulse


## Turn to face a direction; instant=true snaps (used for dodges/attacks).
func face(direction: Vector3, instant := false) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	_facing = direction.normalized()
	if instant:
		_apply_facing(1.0)


func get_facing() -> Vector3:
	return _facing


func horizontal_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func is_bursting() -> bool:
	return _burst_time > 0.0


func is_grounded() -> bool:
	return body.is_on_floor()


func speed_for(gait: Gait) -> float:
	match gait:
		Gait.WALK: return walk_speed
		Gait.SPRINT: return sprint_speed
	return run_speed


func _physics_process(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
		return
	var v := body.velocity
	var on_floor := body.is_on_floor()

	# Vertical: gravity, coyote time and buffered jumps.
	_coyote_time = 0.12 if on_floor else maxf(_coyote_time - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote_time > 0.0 and _burst_time <= 0.0:
		v.y = jump_velocity
		_jump_buffer = 0.0
		_coyote_time = 0.0
		jumped.emit()
	elif not on_floor:
		var g := _gravity * (fall_gravity_multiplier if v.y < 0.0 else 1.0)
		v.y -= g * delta

	# Horizontal.
	var horizontal := Vector3(v.x, 0.0, v.z)
	if _burst_time > 0.0:
		_burst_time -= delta
		horizontal = _burst_velocity
	else:
		var target := _wish_dir * speed_for(_gait) * speed_multiplier()
		var rate := acceleration if target.length() > horizontal.length() else deceleration
		if not on_floor:
			rate *= air_control
		horizontal = horizontal.move_toward(target, rate * delta)
		if _wish_dir.length_squared() > 0.01 and speed_multiplier() > 0.0 and not lock_facing:
			_facing = _wish_dir.normalized()

	horizontal += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 8.0 * delta)
	v.x = horizontal.x
	v.z = horizontal.z
	body.velocity = v
	body.move_and_slide()
	# Don't carry knockback into stored velocity; it's re-added each frame.
	body.velocity.x -= _knockback.x
	body.velocity.z -= _knockback.z

	_apply_facing(delta * turn_speed * turn_multiplier)

	if on_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = on_floor


func _apply_facing(weight: float) -> void:
	var current := -body.global_basis.z
	current.y = 0.0
	if current.length_squared() < 0.0001:
		return
	var angle := current.normalized().signed_angle_to(_facing, Vector3.UP)
	var step := clampf(angle, -weight, weight) if weight < 1.0 else angle
	body.rotate_y(step)
