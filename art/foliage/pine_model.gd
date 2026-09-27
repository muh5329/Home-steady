@tool
extends Node3D
## A full-grown broadleaf tree from the Poly Haven scans (PHModels.TREES),
## so choppable trees and scenery share one look. (Historically a stylized
## pine; the scene names are kept so saves and data stay valid.)

@export var variant := 0:
	set(v):
		variant = v
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var v := variant % PHModels.TREES.size()
	var tree := PHModels.node(PHModels.TREES[v])
	var s: float = PHModels.TREE_SCALE[v]
	tree.scale = Vector3.ONE * s
	# The scans stand on a little sand mound; sink it into the grass.
	tree.position.y = -0.06 * s
	add_child(tree)
