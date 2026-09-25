class_name CarryComponent
extends Node
## Holding one physical item: pick up (animated), carry (speed penalty,
## arm pose), drop, throw, and hand over to receivers (stockpiles,
## construction sites). Shared by the player and every NPC hauler.

signal carrying_changed(carryable: Carryable)

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
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

var carrying: Carryable = null
var _pending_pickup: Carryable = null


func _ready() -> void:
	combat.state_changed.connect(_on_combat_state_changed)


func is_carrying() -> bool:
	return carrying != null or _pending_pickup != null


func is_carrying_heavy() -> bool:
	return carrying != null and carrying.is_heavy()


## Animated pickup. Await it; returns whether the item ended up in hand.
func pick_up(item: Carryable) -> bool:
	if is_carrying() or not item.is_available_for(self):
		return false
	if not combat.perform(pickup_animation, pickup_speed, 0.0, pickup_lock_seconds):
		return false
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
		return false
	_pending_pickup = null
	_hold(item)
	return true


## Immediately holds `item` without animation (loading a save).
func hold_immediately(item: Carryable) -> void:
	_hold(item)


## Removes the carried item from the game entirely (loading a save).
func discard_carried() -> void:
	_pending_pickup = null
	if carrying == null:
		return
	var item := carrying
	_set_carrying(null)
	item.queue_free()


## Hands the carried item to a receiver. Returns whether it was accepted.
func deposit(target: Interactable) -> bool:
	if carrying == null or not target.can_accept(carrying):
		return false
	var item := carrying
	_release(Vector3.ZERO)
	combat.perform(&"Interact", 2.0, 0.0, 0.3)
	return target.receive(item)


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


func _hold(item: Carryable) -> void:
	item.attach_to(self, hold_point)
	_set_carrying(item)


func _set_carrying(item: Carryable) -> void:
	carrying = item
	motor.set_speed_modifier(&"carry", item.speed_modifier() if item else 1.0)
	if carry_pose:
		carry_pose.holding = item != null
	carrying_changed.emit(item)


func _release(velocity: Vector3) -> void:
	var item := carrying
	_set_carrying(null)
	# Don't let the item collide with the carrier while it leaves the hands.
	item.add_collision_exception_with(body)
	item.detach(_world_parent(), velocity)
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


# --- persistence helpers (owners embed these in their own save data) ---------

func save_state() -> String:
	return String(carrying.item_id) if carrying else ""


func load_state(item_id: String) -> void:
	discard_carried()
	var id := StringName(item_id)
	if id == &"" or not DataRegistry.has_data(id):
		return
	var data := DataRegistry.get_data(id) as ItemData
	var item: Carryable = data.carry_scene.instantiate()
	body.add_child(item)
	hold_immediately(item)
