class_name InteractionController
extends Area3D
## The player's "use" key: finds the best Interactable in reach and uses
## it, or hands the carried item to whatever accepts it. Carrying itself
## lives in the shared CarryComponent.

signal focus_changed(interactable: Interactable)
signal carrying_changed(carryable: Carryable)

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var combat: CombatController
@export var carry: CarryComponent

var focused: Interactable = null
var _scan_timer := 0.0

## Convenience pass-throughs used by UI and interactables.
var carrying: Carryable:
	get: return carry.carrying
var carry_pose: CarryPoseModifier:
	get: return carry.carry_pose


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitoring = true
	monitorable = false
	carry.carrying_changed.connect(func(item):
		_update_focus()
		carrying_changed.emit(item))


func is_carrying() -> bool:
	return carry.is_carrying()


func is_carrying_heavy() -> bool:
	return carry.is_carrying_heavy()


func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_update_focus()


func _update_focus() -> void:
	var best: Interactable = null
	# Empty hands: anything usable. Carrying: only things that accept the item.
	if not (carry.is_carrying() and carry.carrying == null):
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
			carry.deposit(focused)
		else:
			carry.drop()
	elif focused and focused.enabled:
		focused.interact(self)


func pick_up(item: Carryable) -> void:
	carry.pick_up(item)


func drop() -> void:
	carry.drop()


func throw() -> void:
	carry.throw()
