extends MeshInstance3D
## Tilled soil ridges under a farm's plots (FoliageMeshes.furrows).

@export var size := Vector2(4.8, 4.4)
@export var rows := 11


func _ready() -> void:
	mesh = FoliageMeshes.furrows(size, rows)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
