class_name Footprint
extends Area3D
## Marks ground as occupied for building placement, including things
## without a solid collider (fields, campfires, stumps, deposit aprons).

const LAYER := 1 << 5  # physics layer 6 "footprints"


static func box(size: Vector3, offset := Vector3.ZERO) -> Footprint:
	var shape := BoxShape3D.new()
	shape.size = size
	return _make(shape, offset + Vector3.UP * size.y * 0.5)


static func cylinder(radius: float, height := 2.0) -> Footprint:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _make(shape, Vector3.UP * height * 0.5)


static func _make(shape: Shape3D, offset: Vector3) -> Footprint:
	var fp := Footprint.new()
	fp.name = "Footprint"
	fp.collision_layer = LAYER
	fp.collision_mask = 0
	fp.monitoring = false
	fp.monitorable = true
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = offset
	fp.add_child(col)
	return fp
