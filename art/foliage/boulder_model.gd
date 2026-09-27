@tool
extends MeshInstance3D
## A mossy boulder: one of the Poly Haven scanned rocks (rock_moss_set_01/02),
## recentred on its base and sized to about 1.3 m across.

const ROCKS := [["rock_moss_set_01", "rock01"], ["rock_moss_set_01", "rock03"], ["rock_moss_set_02", "rock08"], ["rock_moss_set_01", "rock05"], ["rock_moss_set_02", "rock10"], ["rock_moss_set_02", "rock12"]]

static var _meshes: Dictionary = {}

@export var variant := 0:
	set(v):
		variant = v
		mesh = rock(v)


func _ready() -> void:
	if mesh == null:
		mesh = rock(variant)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func rock(v: int, width := 1.3) -> ArrayMesh:
	var key := "%d_%.2f" % [v, width]
	if _meshes.has(key):
		return _meshes[key]
	var r: Array = ROCKS[posmod(v, ROCKS.size())]
	var only := PackedStringArray([r[1]])
	var box := PHModels.bounds(r[0], only)
	var s := width / maxf(maxf(box.size.x, box.size.z), 0.01)
	var centre := box.get_center()
	# Sink the base a little so the rock sits in the ground, not on it.
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * s), -Vector3(centre.x, box.position.y + box.size.y * 0.12, centre.z) * s)
	var m := PHModels.mesh(r[0], only, xf)
	_meshes[key] = m
	return m
