class_name Hitbox
extends Area3D
## Damage volume that is only live during an attack's active frames.
## Each activation hits a given DamageReceiver at most once.

signal hit(receiver: DamageReceiver, event: DamageEvent)

@export var faction: StringName = &"neutral"
## Receivers to ignore (usually the owner's own hurtbox).
@export var ignore: Array[DamageReceiver] = []

var _active := false
var _factory: Callable  # (receiver) -> DamageEvent
var _already_hit: Array[DamageReceiver] = []
var _shape_node: CollisionShape3D
var _default_size := Vector3.ZERO
var _default_offset := Vector3.ZERO


func _ready() -> void:
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			_shape_node = child
			_shape_node.shape = child.shape.duplicate()  # per-instance resize
			_default_size = _shape_node.shape.size
			_default_offset = _shape_node.position
	collision_layer = 0
	collision_mask = DamageReceiver.LAYER
	monitorable = false
	monitoring = false


## Starts a hit window. `event_factory` builds a fresh DamageEvent per victim.
## A non-zero `size`/`offset` reshapes the box for this attack (a thrust
## reaches further than a sweep).
func activate(event_factory: Callable, size := Vector3.ZERO, offset := Vector3.ZERO) -> void:
	if _shape_node:
		_shape_node.shape.size = size if size != Vector3.ZERO else _default_size
		_shape_node.position = offset if size != Vector3.ZERO else _default_offset
	_factory = event_factory
	_already_hit.clear()
	_active = true
	monitoring = true


func deactivate() -> void:
	_active = false
	monitoring = false


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for area in get_overlapping_areas():
		var receiver := area as DamageReceiver
		if receiver == null or receiver in ignore or receiver in _already_hit:
			continue
		if not receiver.can_be_hit_by(faction):
			continue
		_already_hit.append(receiver)
		var event: DamageEvent = _factory.call(receiver)
		event.hit_position = receiver.global_position + Vector3.UP * 1.0
		receiver.receive(event)
		hit.emit(receiver, event)
