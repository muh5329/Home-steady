class_name Interactable
extends Area3D
## Makes its parent usable with the interact key. The parent decides what
## "use" means by connecting to `interacted` (pick up, open, talk...).
## Doors, chests, resource nodes, NPCs and carryables all share this.
##
## Owners that accept carried items (stockpiles, construction sites) also
## set `item_filter` and `item_receiver`; a character carrying something
## then sees "Store <item>" and hands the item over directly.

signal interacted(interactor: InteractionController)

const LAYER := 1 << 3  # physics layer 4 "interactables"

@export var prompt := "Use"
@export var enabled := true
## Higher wins when several are in reach at similar distance.
@export var focus_priority := 0
@export var deposit_verb := "Store"

## (Carryable) -> bool: would the owner take this item right now?
var item_filter: Callable
## (Carryable) -> bool: take the item (the owner consumes or stores it).
var item_receiver: Callable


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt


func interact(interactor: InteractionController) -> void:
	if enabled:
		interacted.emit(interactor)


func can_accept(item: Carryable) -> bool:
	return enabled and item_filter.is_valid() and item_filter.call(item)


func receive(item: Carryable) -> bool:
	return item_receiver.is_valid() and item_receiver.call(item)
