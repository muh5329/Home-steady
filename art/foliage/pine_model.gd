@tool
extends MeshInstance3D
## A procedural stylized pine (FoliageMeshes.pine) as a scene, so resource
## trees and scenery share one look.

@export var variant := 0:
	set(v):
		variant = v
		mesh = FoliageMeshes.pine(v)


func _ready() -> void:
	if mesh == null:
		mesh = FoliageMeshes.pine(variant)
