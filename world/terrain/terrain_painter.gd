class_name TerrainPainter
extends Node3D
## Bakes its PaintStroke children into a world-space paint mask texture for
## the ground shader (R = road, G = cobble, B = tilled) at load. Other
## systems (grass, flowers) ask `coverage(pos)` to stay off paths.

const GROUP := &"terrain_painter"

@export var ground: GeometryInstance3D
## World rectangle covered: min corner (x, z) and size.
@export var rect := Rect2(-80, -80, 160, 160)
@export var pixels_per_metre := 2.0

var _w := 0
var _h := 0
var _channels: Array[PackedFloat32Array] = []
var _texture: ImageTexture
var _image: Image


static func of(node: Node) -> TerrainPainter:
	return node.get_tree().get_first_node_in_group(GROUP) as TerrainPainter


func _ready() -> void:
	add_to_group(GROUP)
	bake()


func bake() -> void:
	_w = int(rect.size.x * pixels_per_metre)
	_h = int(rect.size.y * pixels_per_metre)
	_channels = []
	for i in 3:
		var c := PackedFloat32Array()
		c.resize(_w * _h)
		_channels.append(c)
	for child in get_children():
		if child is PaintStroke:
			_rasterize(child)
	_image = Image.create(_w, _h, false, Image.FORMAT_RGB8)
	_write_pixels(Rect2i(0, 0, _w, _h))
	_texture = ImageTexture.create_from_image(_image)
	if ground and ground.material_override is ShaderMaterial:
		_apply(ground.material_override)
	elif ground is MeshInstance3D and (ground as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial:
		_apply((ground as MeshInstance3D).get_surface_override_material(0))


func _apply(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter(&"paint_mask", _texture)
	mat.set_shader_parameter(&"mask_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


## Paints a soft, ragged disc (a trodden dirt apron under a new building)
## and updates the ground right away. Tilled soil is painted as a crisp
## square field of half-size `radius`, turned by `yaw`.
func paint_disc(centre: Vector3, radius: float, kind := PaintStroke.Kind.ROAD, yaw := 0.0) -> void:
	if _image == null:
		return
	var channel := _channels[int(kind)]
	# Worn ground fades out softly; tilled soil keeps a crisp field edge.
	var feather := 0.5 if kind == PaintStroke.Kind.TILLED else 2.0
	var reach := radius * 1.45 + feather
	var unturn := Basis(Vector3.UP, yaw).inverse()
	var x0 := maxi(int((centre.x - reach - rect.position.x) * pixels_per_metre), 0)
	var x1 := mini(int((centre.x + reach - rect.position.x) * pixels_per_metre), _w - 1)
	var y0 := maxi(int((centre.z - reach - rect.position.y) * pixels_per_metre), 0)
	var y1 := mini(int((centre.z + reach - rect.position.y) * pixels_per_metre), _h - 1)
	if x1 < x0 or y1 < y0:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(rect.position.x + (x + 0.5) / pixels_per_metre, rect.position.y + (y + 0.5) / pixels_per_metre)
			var off := p - Vector2(centre.x, centre.z)
			var d := off.length()
			var r := radius
			if kind == PaintStroke.Kind.TILLED:
				var local := unturn * Vector3(off.x, 0.0, off.y)
				d = maxf(absf(local.x), absf(local.z))
			else:
				# A ragged, trodden edge rather than a stamped circle.
				var ang := off.angle()
				r = radius * (1.0 + 0.14 * sin(ang * 3.0 + centre.x) + 0.08 * sin(ang * 7.0 + centre.z))
			var v := clampf(1.0 - (d - r) / feather, 0.0, 1.0) if d > r else 1.0
			var i := y * _w + x
			channel[i] = maxf(channel[i], v)
	_write_pixels(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	_texture.update(_image)


func _write_pixels(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * _w + x
			_image.set_pixel(x, y, Color(_channels[0][i], _channels[1][i], _channels[2][i]))


## 0..1 coverage of paths/plazas/fields at a world position (max channel).
func coverage(pos: Vector3) -> float:
	var x := int((pos.x - rect.position.x) * pixels_per_metre)
	var y := int((pos.z - rect.position.y) * pixels_per_metre)
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return 0.0
	var i := y * _w + x
	return maxf(_channels[0][i], maxf(_channels[1][i], _channels[2][i]))


func _rasterize(stroke: PaintStroke) -> void:
	var points := stroke.curve.get_baked_points()
	if points.size() < 2:
		return
	var channel := _channels[int(stroke.kind)]
	var half := stroke.width * 0.5
	var reach := half + 1.5
	for s in points.size() - 1:
		var a := stroke.to_global(points[s])
		var b := stroke.to_global(points[s + 1])
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var lo := Vector2(minf(a2.x, b2.x), minf(a2.y, b2.y)) - Vector2(reach, reach)
		var hi := Vector2(maxf(a2.x, b2.x), maxf(a2.y, b2.y)) + Vector2(reach, reach)
		var x0 := maxi(int((lo.x - rect.position.x) * pixels_per_metre), 0)
		var x1 := mini(int((hi.x - rect.position.x) * pixels_per_metre), _w - 1)
		var y0 := maxi(int((lo.y - rect.position.y) * pixels_per_metre), 0)
		var y1 := mini(int((hi.y - rect.position.y) * pixels_per_metre), _h - 1)
		var ab := b2 - a2
		var len2 := maxf(ab.length_squared(), 0.0001)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(rect.position.x + (x + 0.5) / pixels_per_metre, rect.position.y + (y + 0.5) / pixels_per_metre)
				var t := clampf((p - a2).dot(ab) / len2, 0.0, 1.0)
				var d := p.distance_to(a2 + ab * t)
				# 1 in the middle, falling to 0 over the last metre past the edge.
				var v := clampf(1.0 - (d - half) / 1.5, 0.0, 1.0) if d > half else 1.0
				var i := y * _w + x
				if v > channel[i]:
					channel[i] = v
