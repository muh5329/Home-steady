@tool
extends Node3D
## Places a Poly Haven model (PHModels) by name, e.g. a tree stump, fire pit
## ring or lantern, in a scene.

@export var model := "tree_stump_01":
	set(v):
		model = v
		if is_inside_tree():
			_rebuild()
## Only parts whose node name contains one of these (empty = all).
@export var only: PackedStringArray = []
@export var model_scale := 1.0
@export var sink := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var n := PHModels.node(model, only)
	n.scale = Vector3.ONE * model_scale
	n.position.y = -sink
	add_child(n)
