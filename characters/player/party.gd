class_name Party
extends Node
## The player's adventuring party: which settlers currently follow as
## companions, in join order (the order picks formation slots and HUD
## frames). Settlers register themselves when they switch to companion
## mode, so a loaded save rebuilds the party without extra bookkeeping.

signal members_changed

const GROUP := &"party"
const MAX_COMPANIONS := 3

## Formation slots relative to the leader (x right, z back), by join order.
const SLOTS: Array[Vector3] = [Vector3(-1.8, 0, 2.2), Vector3(1.8, 0, 2.2), Vector3(0, 0, 3.6)]

var _members: Array[Settler] = []


static func of(node: Node) -> Party:
	return node.get_tree().get_first_node_in_group(GROUP) as Party


func _ready() -> void:
	add_to_group(GROUP)


func members() -> Array[Settler]:
	_members = _members.filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
	return _members


func is_full() -> bool:
	return members().size() >= MAX_COMPANIONS


func has(member: Settler) -> bool:
	return member in members()


func add(member: Settler) -> bool:
	if has(member):
		return true
	if is_full():
		return false
	_members.append(member)
	members_changed.emit()
	return true


func remove(member: Settler) -> void:
	if member in _members:
		_members.erase(member)
		members_changed.emit()


## Party-wide order (one key): if anyone is following, everyone holds
## where they stand; otherwise everyone follows again. Returns the order
## given ("hold"/"follow"), or "" with no companions.
func toggle_orders() -> String:
	var list := members()
	if list.is_empty():
		return ""
	var anyone_following := list.any(func(m): return m.companion.order == CompanionController.Order.FOLLOW)
	for m in list:
		if anyone_following:
			m.order_hold()
		else:
			m.order_follow()
	return "hold" if anyone_following else "follow"


## Where `member` should stand, given the leader's position and facing.
func formation_point(member: Settler, leader: Node3D, facing: Vector3) -> Vector3:
	var i := maxi(members().find(member), 0)
	var slot := SLOTS[i % SLOTS.size()]
	var forward := NavSteering.flat(facing).normalized()
	if forward == Vector3.ZERO:
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	return leader.global_position + right * slot.x - forward * slot.z
