@tool
extends MeshInstance3D
## A procedural mossy boulder (FoliageMeshes.boulder) as a scene.

@export var variant := 0:
	set(v):
		variant = v
		mesh = FoliageMeshes.boulder(v)


func _ready() -> void:
	if mesh == null:
		mesh = FoliageMeshes.boulder(variant)
