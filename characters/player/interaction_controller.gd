class_name InteractionController
extends Area3D
## Finds the best Interactable in reach, and handles carrying physical
## objects (pick up, drop, throw). Lives on the player; companions can
## reuse it later since it only talks to shared components.

signal focus_changed(interactable: Interactable)
signal carrying_changed(carryable: Carryable)

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var animator: CharacterAnimator
@export var hold_point: Node3D
@export var carry_pose: CarryPoseModifier

@export_group("Pick up")
@export var pickup_animation: StringName = &"PickUp"
@export var pickup_speed := 1.6
@export var pickup_lock_seconds := 0.5
## When the hands reach the object in the (sped-up) clip.
@export var pickup_attach_seconds := 0.25

@export_group("Throw")
@export var throw_animation: StringName = &"Throw"
@export var throw_speed_scale := 1.4
@export var throw_lock_seconds := 0.55
## Release frame of the throw clip at throw_speed_scale.
@export var throw_release_seconds := 0.42
@export var throw_speed := 9.0
@export var throw_lift := 3.5

var focused: Interactable = null
var carrying: Carryable = null
var _pending_pickup: Carryable = null
var _scan_timer := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitoring = true
	monitorable = false
	combat.state_changed.connect(_on_combat_state_changed)


func is_carrying() -> bool:
	return carrying != null or _pending_pickup != null


func is_carrying_heavy() -> bool:
	return carrying != null and carrying.is_heavy()


func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_update_focus()


func _update_focus() -> void:
	var best: Interactable = null
	# Empty hands: anything usable. Carrying: only things that accept the item.
	if _pending_pickup == null:
		var best_score := INF
		var facing := motor.get_facing()
		for area in get_overlapping_areas():
			var candidate := area as Interactable
			if candidate == null or not candidate.enabled:
				continue
			if carrying and not candidate.can_accept(carrying):
				continue
			var offset := candidate.global_position - body.global_position
			offset.y = 0.0
			var dist := offset.length()
			var angle_penalty := (1.0 - offset.normalized().dot(facing)) * 1.2 if dist > 0.01 else 0.0
			var score := dist + angle_penalty - candidate.focus_priority
			if score < best_score:
				best_score = score
				best = candidate
	if best != focused:
		focused = best
		focus_changed.emit(focused)


## Primary interaction: use the focused thing, hand the carried item to
## whatever accepts it, or put it down.
func interact() -> void:
	if carrying:
		if focused and focused.can_accept(carrying):
			deposit(focused)
		else:
			drop()
	elif focused and focused.enabled:
		focused.interact(self)


## Hands the carried item to a receiver (stockpile, construction site).
func deposit(target: Interactable) -> bool:
	if carrying == null or not target.can_accept(carrying):
		return false
	var item := carrying
	_release(Vector3.ZERO)
	combat.perform(&"Interact", 2.0, 0.0, 0.3)
	if target.receive(item):
		_update_focus()
		return true
	return false


func pick_up(item: Carryable) -> void:
	if is_carrying() or not item.is_available():
		return
	if not combat.perform(pickup_animation, pickup_speed, 0.0, pickup_lock_seconds):
		return
	item.claim(self)
	_pending_pickup = item
	motor.face(item.global_position - body.global_position, true)
	await get_tree().create_timer(pickup_attach_seconds, false, true).timeout
	# Anything may have happened meanwhile (hit, death, someone else took it).
	if _pending_pickup != item or not is_instance_valid(item) or item.is_carried() \
			or combat.state != CombatController.CombatState.BUSY:
		if is_instance_valid(item):
			item.release_claim(self)
		_pending_pickup = null
		return
	_pending_pickup = null
	carrying = item
	item.attach_to(self, hold_point)
	motor.set_speed_modifier(&"carry", item.speed_modifier())
	if carry_pose:
		carry_pose.holding = true
	_update_focus()
	carrying_changed.emit(carrying)


## Immediately holds `item` without animation (used when loading a save).
func hold_immediately(item: Carryable) -> void:
	carrying = item
	item.attach_to(self, hold_point)
	motor.set_speed_modifier(&"carry", item.speed_modifier())
	if carry_pose:
		carry_pose.holding = true
	carrying_changed.emit(carrying)


## Removes the carried item from the game entirely (used when loading).
func discard_carried() -> void:
	_pending_pickup = null
	if carrying == null:
		return
	var item := carrying
	carrying = null
	motor.set_speed_modifier(&"carry", 1.0)
	if carry_pose:
		carry_pose.holding = false
	item.queue_free()
	carrying_changed.emit(null)


func drop() -> void:
	if carrying == null:
		return
	var item := carrying
	_release(Vector3.ZERO)
	# Set it down just in front of the carrier.
	item.global_position = body.global_position + motor.get_facing() * 1.0 + Vector3.UP * 0.6


func throw() -> void:
	if carrying == null:
		return
	var item := carrying
	if not combat.perform(throw_animation, throw_speed_scale, 0.2, throw_lock_seconds):
		return
	await get_tree().create_timer(throw_release_seconds, false, true).timeout
	if carrying != item or combat.state != CombatController.CombatState.BUSY:
		return
	var velocity := motor.get_facing() * throw_speed + Vector3.UP * throw_lift
	if item.is_heavy():
		velocity *= 0.6
	_release(velocity)


func _release(velocity: Vector3) -> void:
	var item := carrying
	carrying = null
	motor.set_speed_modifier(&"carry", 1.0)
	if carry_pose:
		carry_pose.holding = false
	# Don't let the item collide with the carrier while it leaves the hands.
	item.add_collision_exception_with(body)
	item.detach(_world_parent(), velocity)
	carrying_changed.emit(null)
	await get_tree().create_timer(0.4, false, true).timeout
	if is_instance_valid(item) and is_instance_valid(body):
		item.remove_collision_exception_with(body)


## Getting hit or dying makes you lose your grip.
func _on_combat_state_changed(state: CombatController.CombatState) -> void:
	if state in [CombatController.CombatState.STAGGERED, CombatController.CombatState.DEAD]:
		if _pending_pickup and is_instance_valid(_pending_pickup):
			_pending_pickup.release_claim(self)
		_pending_pickup = null
		if carrying:
			var item := carrying
			_release(Vector3.UP * 1.5)
			item.global_position = body.global_position + motor.get_facing() * 0.8 + Vector3.UP * 0.9


func _world_parent() -> Node:
	var root := get_tree().get_first_node_in_group(WorldItems.GROUP)
	return root if root else body.get_parent()
