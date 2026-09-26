extends Node3D
## A little wooden planter box brimming with flowers: the colour accents
## that sit against storybook walls.

@export var petal := Color(0.95, 0.5, 0.65)
@export var length := 1.1

static var _box_mat: StandardMaterial3D


func _ready() -> void:
	if _box_mat == null:
		_box_mat = StandardMaterial3D.new()
		_box_mat.albedo_color = Color(0.55, 0.33, 0.2)
		_box_mat.roughness = 0.9
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.32, 0.42)
	bm.material = _box_mat
	box.mesh = bm
	box.position.y = 0.16
	add_child(box)
	var soil := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(length - 0.08, 0.02, 0.34)
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.3, 0.2, 0.13)
	sm.material = soil_mat
	soil.mesh = sm
	soil.position.y = 0.31
	add_child(soil)
	var count := int(length / 0.3) + 1
	for i in count:
		var f := MeshInstance3D.new()
		f.mesh = FoliageMeshes.flower(petal if i % 2 == 0 else Color(0.98, 0.95, 0.88))
		f.position = Vector3(-length * 0.5 + (i + 0.5) * length / count, 0.3, 0)
		f.scale = Vector3.ONE * 1.3
		f.rotation.y = i * 1.7
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
	var leaves := MeshInstance3D.new()
	leaves.mesh = FoliageMeshes.bush(1)
	leaves.scale = Vector3(length * 0.55, 0.35, 0.3)
	leaves.position.y = 0.3
	add_child(leaves)
