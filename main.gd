extends Node
## Boot scene: instantiates the starting region. Kept minimal on purpose;
## menus and region streaming arrive only when the game needs them.

@export var start_region: PackedScene


func _ready() -> void:
	if start_region:
		add_child(start_region.instantiate())
