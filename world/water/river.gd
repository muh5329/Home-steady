class_name River
extends Node3D
## A river through the land: it paints sandy banks, sinks the ground under
## it (the ground shader displaces by a depth mask this node bakes), lays a
## water surface along its course and walls off the deep water so people
## stay on the banks. `depth_at(pos)` lets other systems keep off it.

const GROUP := &"water"
const WATER_SHADER := preload("res://art/environments/materials/water.gdshader")

## Course of the river, world (x, z), smoothed with a Catmull-Rom spline.
@export var points: PackedVector2Array = []
@export var width := 12.0
@export var bank_width := 1.0
@export var depth := 1.8
@export var water_level := -0.3
## Area the depth mask covers (min x, min z, size) and its resolution.
@export var mask_rect := Rect2(-130, -130, 260, 260)
@export var pixels_per_metre := 1.0
## Ground materials whose shaders sink under the river.
@export var ground_materials: Array[ShaderMaterial] = []

var course := PackedVector2Array()
## Baked masks are the same every load of a level: keep them.
static var _bake_cache: Dictionary = {}
var _mask: Image
var _dist := PackedFloat32Array()  # distance to the course, per mask pixel
var _w := 0
var _h := 0


func _ready() -> void:
	add_to_group(GROUP)
	course = _smooth(points)
	_bake_mask()
	_build_surface()
	_build_banks()
	# The painter bakes on its own _ready; banks go on top once it exists.
	(func():
		var painter := TerrainPainter.of(self)
		if painter:
			painter.paint_polyline(course, width + bank_width * 2.0, PaintStroke.Kind.SAND)).call_deferred()


## 0 on dry land, rising to 1 in the deep middle.
func depth_at(pos: Vector3) -> float:
	var x := int((pos.x - mask_rect.position.x) * pixels_per_metre)
	var y := int((pos.z - mask_rect.position.y) * pixels_per_metre)
	if _mask == null or x < 0 or y < 0 or x >= _w or y >= _h:
		return 0.0
	return _mask.get_pixel(x, y).r


## Within the river or its sandy banks (keep grass and buildings off).
func covers(pos: Vector3, margin := 0.0) -> bool:
	var x := int((pos.x - mask_rect.position.x) * pixels_per_metre)
	var y := int((pos.z - mask_rect.position.y) * pixels_per_metre)
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return false
	return _dist[y * _w + x] < width * 0.5 + bank_width + margin


static func depth_of(node: Node, pos: Vector3) -> float:
	var best := 0.0
	for r in node.get_tree().get_nodes_in_group(GROUP):
		best = maxf(best, (r as River).depth_at(pos))
	return best


static func covered(node: Node, pos: Vector3, margin := 0.0) -> bool:
	for r in node.get_tree().get_nodes_in_group(GROUP):
		if (r as River).covers(pos, margin):
			return true
	return false


func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		var steps := maxi(int(p1.distance_to(p2) / 2.0), 2)
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _distance(p: Vector2) -> float:
	var best := INF
	for i in course.size() - 1:
		var a := course[i]
		var b := course[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _bake_mask() -> void:
	_w = int(mask_rect.size.x * pixels_per_metre)
	_h = int(mask_rect.size.y * pixels_per_metre)
	var key := hash([points, width, bank_width, mask_rect, pixels_per_metre])
	if not _bake_cache.has(key):
		_bake_cache[key] = _compute_mask()
	var baked: Array = _bake_cache[key]
	_dist = baked[0]
	_mask = baked[1]
	var tex := ImageTexture.create_from_image(_mask)
	for m in ground_materials:
		m.set_shader_parameter(&"water_mask", tex)
		m.set_shader_parameter(&"water_rect", Vector4(mask_rect.position.x, mask_rect.position.y, mask_rect.size.x, mask_rect.size.y))
		m.set_shader_parameter(&"water_depth", depth)


func _compute_mask() -> Array:
	var dist := PackedFloat32Array()
	dist.resize(_w * _h)
	dist.fill(1e9)
	var reach := width * 0.5 + bank_width + 6.0
	for i in course.size() - 1:
		var a := course[i]
		var b := course[i + 1]
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
		var x0 := maxi(int((lo.x - mask_rect.position.x) * pixels_per_metre), 0)
		var x1 := mini(int((hi.x - mask_rect.position.x) * pixels_per_metre), _w - 1)
		var y0 := maxi(int((lo.y - mask_rect.position.y) * pixels_per_metre), 0)
		var y1 := mini(int((hi.y - mask_rect.position.y) * pixels_per_metre), _h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(mask_rect.position.x + (x + 0.5) / pixels_per_metre, mask_rect.position.y + (y + 0.5) / pixels_per_metre)
				var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				var idx := y * _w + x
				if d < dist[idx]:
					dist[idx] = d
	var mask := Image.create(_w, _h, false, Image.FORMAT_RF)
	var half := width * 0.5
	for y in _h:
		for x in _w:
			var d := dist[y * _w + x]
			if d > half + 1.0:
				continue
			# Bank slopes from 1 m outside the waterline to the full depth
			# 3.5 m in: a gentle beach, then a channel.
			var v := 0.0
			if d < half + 1.0:
				v = smoothstep(half + 1.0, half - 3.5, d)
			mask.set_pixel(x, y, Color(v, 0, 0))
	return [dist, mask]


func _build_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5 + 1.2
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in course.size():
		var a := course[maxi(i - 1, 0)]
		var b := course[mini(i + 1, course.size() - 1)]
		var tangent := (b - a).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var c := course[i]
		left.append(Vector3(c.x + side.x * half, water_level, c.y + side.y * half))
		right.append(Vector3(c.x - side.x * half, water_level, c.y - side.y * half))
	for i in course.size() - 1:
		var q := [left[i], right[i], right[i + 1], left[i + 1]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[idx].x, q[idx].z))
			st.add_vertex(q[idx])
	st.index()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	for key in [&"ripple_a", &"ripple_b"]:
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 6.0 if key == &"ripple_a" else 3.0
		var n := FastNoiseLite.new()
		n.frequency = 0.03 if key == &"ripple_a" else 0.05
		n.fractal_octaves = 3
		n.seed = 11 if key == &"ripple_a" else 23
		nt.noise = n
		mat.set_shader_parameter(key, nt)
	var foam := NoiseTexture2D.new()
	foam.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	foam.noise = fn
	mat.set_shader_parameter(&"foam_noise", foam)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


## Invisible walls just inside the waterline so nobody wades in.
func _build_banks() -> void:
	var body := StaticBody3D.new()
	body.name = "Banks"
	body.collision_mask = 0
	add_child(body)
	var offset := width * 0.5 - 1.0
	for i in course.size() - 1:
		var a := course[i]
		var b := course[i + 1]
		var tangent := (b - a).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var length := a.distance_to(b) + 0.4
		for sgn in [-1.0, 1.0]:
			var mid: Vector2 = (a + b) * 0.5 + side * offset * sgn
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 3.0, length)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.transform = Transform3D(Basis(Vector3.UP, atan2(tangent.x, tangent.y)), Vector3(mid.x, 1.0, mid.y))
			body.add_child(cs)
