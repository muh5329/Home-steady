class_name HousingComponent
extends Node
## Beds provided by a building. Settlers (Phase 7) need free beds to move in.

const GROUP := &"housing"

@export var beds := 4


func _ready() -> void:
	add_to_group(GROUP)
