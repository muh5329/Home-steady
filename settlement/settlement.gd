class_name Settlement
extends Node
## Per-region logistics service: where things are stored, what's needed,
## what's free to work on. Workers, storages, construction and the HUD ask
## this instead of scanning groups themselves.

const GROUP := &"settlement"
const CONSTRUCTION_GROUP := &"construction_sites"


static func of(node: Node) -> Settlement:
	return node.get_tree().get_first_node_in_group(GROUP) as Settlement


func _ready() -> void:
	add_to_group(GROUP)


# --- storage ------------------------------------------------------------------

func storages() -> Array[Stockpile]:
	var out: Array[Stockpile] = []
	for s in get_tree().get_nodes_in_group(Stockpile.GROUP):
		out.append(s)
	return out


## Nearest storage that would accept one `item` right now.
func find_storage_for(item: Carryable, from: Vector3) -> Stockpile:
	var best: Stockpile = null
	var best_d := INF
	for s in storages():
		if not s.accepts(item):
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## The nearest thing that would take `item` right now (its Interactable).
## Today that's storage; haulers will add construction sites/workshops.
func find_receiver_for(item: Carryable, from: Vector3, skip := Callable()) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for s in storages():
		var r: Interactable = s.interactable
		if not r.can_accept(item) or (skip.is_valid() and skip.call(r)):
			continue
		var d := from.distance_squared_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


## Settlement-wide stored totals: item id -> count.
func totals() -> Dictionary:
	var out := {}
	for s in storages():
		for id in s.inventory.item_ids():
			out[id] = out.get(id, 0) + s.inventory.count(id)
	return out


func settler_count() -> int:
	return get_tree().get_nodes_in_group(Settler.GROUP).filter(func(s): return s.is_member()).size()


func free_beds() -> int:
	return beds() - settler_count()


func beds() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group(HousingComponent.GROUP):
		n += h.beds
	return n


# --- construction demand -------------------------------------------------------

## Items still needed by all construction sites: item id -> amount.
func construction_demand() -> Dictionary:
	var out := {}
	for site in get_tree().get_nodes_in_group(CONSTRUCTION_GROUP):
		var n: Dictionary = site.needs()
		for id in n:
			out[id] = out.get(id, 0) + n[id]
	return out


# --- work ----------------------------------------------------------------------

## Nearest WorkTarget offering work to `job`, not claimed by someone else,
## within range. `skip` (optional Callable(target) -> bool) lets the caller
## exclude targets (blacklisted, near a threat...).
func find_work_target(job: JobDefinition, from: Vector3, max_distance: float, claimant: Object,
		skip := Callable()) -> Node3D:
	var best: Node3D = null
	var best_d := max_distance * max_distance
	for node: Node3D in get_tree().get_nodes_in_group(WorkTarget.GROUP):
		if not node.has_work_for(job) or not node.can_claim(claimant):
			continue
		if skip.is_valid() and skip.call(node):
			continue
		var d := from.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Nearest loose, unclaimed physical item of any of `item_ids` within `radius`.
func find_loose_item(item_ids: Array[StringName], from: Vector3, radius: float) -> Carryable:
	var best: Carryable = null
	var best_d := radius * radius
	var root := get_tree().get_first_node_in_group(WorldItems.GROUP)
	if root == null:
		return null
	for c in root.get_children():
		var item := c as Carryable
		if item == null or item.item_id not in item_ids or not item.is_available() \
				or not item.visible or item.is_queued_for_deletion():
			continue
		var d := from.distance_squared_to(item.global_position)
		if d < best_d:
			best_d = d
			best = item
	return best
