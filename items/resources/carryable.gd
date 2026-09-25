class_name Carryable
extends RigidBody3D
## A physical object that can be picked up, carried, dropped and thrown.
## Logs, stone blocks, crates, sacks and treasure are all Carryables; what
## they *are* (their item id) is data, their handling is shared.

## Everything else about the item (weight, speed, storage) is in its
## ItemData, looked up by this id.
@export var item_id: StringName
## Where the object sits relative to the carrier's hold point.
@export var hold_offset := Vector3.ZERO
@export var hold_rotation_degrees := Vector3.ZERO

var carrier: InteractionController = null
## Someone is on their way to / in the middle of picking this up. Storage
## and other haulers leave claimed items alone.
var claimed_by: Object = null

var data: ItemData

var _saved_layer := 0
var _saved_mask := 0
var _interactable: Interactable


static var _grippy: PhysicsMaterial


func _ready() -> void:
	# Thrown and dropped items should settle, not roll away.
	if physics_material_override == null:
		if _grippy == null:
			_grippy = PhysicsMaterial.new()
			_grippy.friction = 1.0
			_grippy.rough = true
			_grippy.bounce = 0.05
		physics_material_override = _grippy
	angular_damp = maxf(angular_damp, 3.0)
	linear_damp = maxf(linear_damp, 0.4)
	if item_id != &"" and DataRegistry.has_data(item_id):
		data = DataRegistry.get_data(item_id) as ItemData
	for child in get_children():
		if child is Interactable:
			_interactable = child
	if _interactable:
		_interactable.interacted.connect(_on_interacted)


func is_carried() -> bool:
	return carrier != null


## Free to be picked up, stored or hauled.
func is_available() -> bool:
	return carrier == null and (claimed_by == null or not is_instance_valid(claimed_by))


func claim(by: Object) -> bool:
	if not is_available():
		return false
	claimed_by = by
	return true


func release_claim(by: Object) -> void:
	if claimed_by == by:
		claimed_by = null


func is_heavy() -> bool:
	return data != null and data.heavy


## Movement multiplier applied to whoever carries this.
func speed_modifier() -> float:
	return data.carry_speed if data else 0.9


func display_name() -> String:
	return data.display_name if data else String(item_id)


func _on_interacted(by: InteractionController) -> void:
	if is_available():
		by.pick_up(self)


## Called by the InteractionController once the pickup animation lands.
func attach_to(by: InteractionController, hold_point: Node3D) -> void:
	carrier = by
	_saved_layer = collision_layer
	_saved_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	if _interactable:
		_interactable.enabled = false
		_interactable.monitorable = false
	claimed_by = null
	reparent(hold_point, false)
	position = hold_offset
	rotation_degrees = hold_rotation_degrees


## Returns the object to the world at its current position with `velocity`.
func detach(world_parent: Node, velocity: Vector3) -> void:
	var xform := global_transform
	reparent(world_parent, false)
	global_transform = xform
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	freeze = false
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * \
		clampf(velocity.length() / 6.0, 0.0, 1.0)
	if _interactable:
		_interactable.enabled = true
		_interactable.monitorable = true
	carrier = null
