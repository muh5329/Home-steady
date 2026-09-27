@tool
extends Node3D
## One Medieval Village kit piece with the village materials applied
## (a wagon, a fence, a vine) for hand-placed set dressing.

@export var piece := "Prop_Wagon":
	set(v):
		piece = v
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.free()
	add_child(VillageKit.piece(piece))
