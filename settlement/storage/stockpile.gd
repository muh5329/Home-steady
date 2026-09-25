class_name Stockpile
extends Node3D
## An open-air storage area. Physical items that come to rest inside its
## zone are absorbed into its inventory and shown piled on it. Interacting
## with empty hands takes one item back out as a physical object.

const GROUP := &"storages"
const SETTLE_SPEED := 1.2  # items must (nearly) stop moving to be stored

@export var inventory: InventoryComponent
@export var zone: Area3D
@export var interactable: Interactable
## Where stacked visuals are laid out (local XZ grid on top of this node).
@export var stack_origin: Node3D
## Stacked visuals fill a footprint grid, then pile up to max_layers.
@export var grid_size := Vector2i(3, 3)
@export var cell_size := Vector2(1.05, 1.05)
@export var max_layers := 3
## Show stored units as piles (off for enclosed storehouses).
@export var show_stacks := true
## False when part of a Building (the Building persists it instead).
@export var standalone_persistence := true

var _candidates: Array[Carryable] = []
var _visuals: Dictionary = {}  # item_id -> Array[Node3D]
var _check_timer := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP if standalone_persistence else Building.FEATURE_GROUP)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(func(b): _candidates.erase(b))
	inventory.changed.connect(_on_inventory_changed)
	interactable.interacted.connect(_on_interacted)
	interactable.item_filter = accepts
	interactable.item_receiver = try_store
	interactable.deposit_verb = "Store"
	# Pallets and storehouse counters aren't walkable; use from the edge.
	interactable.approach_radius = maxf(interactable.approach_radius, 3.0)
	_update_prompt()


func _on_body_entered(body: Node3D) -> void:
	var item := body as Carryable
	if item and item not in _candidates and item.data and item.data.storable:
		_candidates.append(item)


## Would this stockpile take the item right now?
func accepts(item: Carryable) -> bool:
	return item.data != null and item.data.storable and inventory.free_space() > 0


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0 or _candidates.is_empty():
		return
	_check_timer = 0.15
	for item in _candidates.duplicate():
		if not is_instance_valid(item):
			_candidates.erase(item)
		elif item.is_available() and item.linear_velocity.length() < SETTLE_SPEED:
			try_store(item)


## Absorbs a physical item. Returns true if it was stored.
func try_store(item: Carryable) -> bool:
	if not accepts(item):
		return false
	inventory.add(item.item_id)
	_candidates.erase(item)
	item.queue_free()
	return true


## Takes one unit out as a physical item. Returns it (or null).
func take(item_id: StringName) -> Carryable:
	var data := _item_data(item_id)
	if data == null or inventory.remove(item_id) == 0:
		return null
	var body: Carryable = data.carry_scene.instantiate()
	var parent := get_tree().get_first_node_in_group(WorldItems.GROUP)
	(parent if parent else get_parent()).add_child(body)
	body.global_position = stack_origin.global_position + Vector3.UP * 0.8
	return body


func _on_interacted(by: InteractionController) -> void:
	var ids := inventory.item_ids()
	if ids.is_empty() or by.is_carrying():
		return
	var body := take(_best_item_to_take(ids))
	if body:
		# Keep it from being re-absorbed while it's handed over.
		_candidates.erase(body)
		by.pick_up(body)


## Prefer what construction sites still need; otherwise what we have most of.
func _best_item_to_take(ids: Array[StringName]) -> StringName:
	var settlement := Settlement.of(self)
	var demand := settlement.construction_demand() if settlement else {}
	var best := ids[0]
	var best_score := -1.0
	for id in ids:
		var score := float(inventory.count(id)) + (1000.0 if demand.get(id, 0) > 0 else 0.0)
		if score > best_score:
			best_score = score
			best = id
	return best


func _on_inventory_changed(item_id: StringName, count: int) -> void:
	_update_visuals(item_id, count)
	_update_prompt()
	EventBus.storage_changed.emit(self)


func _update_prompt() -> void:
	var ids := inventory.item_ids()
	if ids.is_empty():
		interactable.prompt = "Stockpile (empty) — drop resources here"
	else:
		var parts: PackedStringArray = []
		for id in ids:
			var data := _item_data(id)
			parts.append("%s %d" % [data.display_name if data else String(id), inventory.count(id)])
		interactable.prompt = "Take from stockpile  (%s)  %d/%d" % [
			", ".join(parts), inventory.total(), inventory.capacity]


# --- visuals: each stored unit is shown on the pile ---------------------------

func _update_visuals(item_id: StringName, count: int) -> void:
	if not show_stacks:
		return
	var data := _item_data(item_id)
	if data == null or data.stack_visual == null:
		return
	var list: Array = _visuals.get(item_id, [])
	while list.size() < count:
		var v: Node3D = data.stack_visual.instantiate()
		v.scale = Vector3.ONE * data.stack_visual_scale
		stack_origin.add_child(v)
		list.append(v)
	while list.size() > count:
		list.pop_back().queue_free()
	_visuals[item_id] = list
	_layout()


func _layout() -> void:
	# Each item type claims whole cells of the footprint grid; a cell holds
	# up to max_layers units stacked. Units beyond the grid are not drawn.
	var cell := 0
	var cells := grid_size.x * grid_size.y
	for item_id in _visuals:
		var data := _item_data(item_id)
		var list: Array = _visuals[item_id]
		for i in list.size():
			var c := cell + i / max_layers
			var v: Node3D = list[i]
			v.visible = c < cells
			if not v.visible:
				continue
			var gx := c % grid_size.x
			var gy := c / grid_size.x
			var layer := i % max_layers
			v.position = Vector3((gx - (grid_size.x - 1) * 0.5) * cell_size.x,
				layer * data.stack_height,
				(gy - (grid_size.y - 1) * 0.5) * cell_size.y)
			v.rotation.y = PI * 0.5 * (layer % 2)  # cross-hatched layers
		cell += ceili(list.size() / float(max_layers))


static func _item_data(item_id: StringName) -> ItemData:
	if not DataRegistry.has_data(item_id):
		return null
	return DataRegistry.get_data(item_id) as ItemData


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "storage:%s" % get_path()


func save_state() -> Dictionary:
	return {"items": inventory.to_dict()}


func load_state(state: Dictionary) -> void:
	inventory.from_dict(state.get("items", {}))
