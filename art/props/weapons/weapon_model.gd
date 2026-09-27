@tool
class_name WeaponModel
extends MeshInstance3D
## Hand-held gear built in code with realistic proportions (the old KayKit
## weapons were chibi-sized rig parts). Convention: the grip is at the
## origin and the handle runs along +Y; a shield faces +Z.

enum Kind { ARMING_SWORD, ROUND_SHIELD, HAND_AXE, CROSSBOW, STAFF, WOODAXE, PICKAXE, SICKLE, HAMMER, GRAVE_SHIELD, GRAVE_SWORD }

@export var kind := Kind.ARMING_SWORD:
	set(v):
		kind = v
		if is_inside_tree() or Engine.is_editor_hint():
			mesh = build(v)

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


func _ready() -> void:
	mesh = build(kind)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func build(k: Kind) -> ArrayMesh:
	if _cache.has(k):
		return _cache[k]
	var parts := {}  # material name -> SurfaceTool
	match k:
		Kind.ARMING_SWORD:
			_cyl(_st(parts, "leather"), Vector3(0, -0.07, 0), Vector3(0, 0.07, 0), 0.016, 0.016, 8)
			_sphere(_st(parts, "iron"), Vector3(0, -0.095, 0), 0.028)
			_box(_st(parts, "iron"), Vector3(0, 0.085, 0), Vector3(0.21, 0.022, 0.03))
			_blade(_st(parts, "steel"), 0.1, 0.86, 0.048, 0.008)
		Kind.ROUND_SHIELD:
			_disc(_st(parts, "shield_wood"), Vector3(0, 0, 0.06), 0.3, 0.024, 28)
			_ring(_st(parts, "iron"), Vector3(0, 0, 0.06), 0.3, 0.018, 0.03, 28)
			_sphere(_st(parts, "iron"), Vector3(0, 0, 0.085), 0.065)
			_box(_st(parts, "leather"), Vector3(0, 0, 0.035), Vector3(0.03, 0.16, 0.02))
		Kind.GRAVE_SHIELD:
			_disc(_st(parts, "grave_wood"), Vector3(0, 0, 0.06), 0.3, 0.024, 28)
			_ring(_st(parts, "rust"), Vector3(0, 0, 0.06), 0.3, 0.018, 0.03, 28)
			_sphere(_st(parts, "rust"), Vector3(0, 0, 0.085), 0.065)
		Kind.GRAVE_SWORD:
			_cyl(_st(parts, "grave_wood"), Vector3(0, -0.07, 0), Vector3(0, 0.07, 0), 0.016, 0.016, 8)
			_box(_st(parts, "rust"), Vector3(0, 0.085, 0), Vector3(0.2, 0.022, 0.03))
			_blade(_st(parts, "rust"), 0.1, 0.8, 0.05, 0.009)
		Kind.HAND_AXE, Kind.WOODAXE:
			_cyl(_st(parts, "wood"), Vector3(0, -0.12, 0), Vector3(0, 0.5, 0), 0.017, 0.015, 8)
			var head := _st(parts, "iron")
			_wedge(head, Vector3(0, 0.44, 0), 0.16, 0.1, 0.025)
		Kind.PICKAXE:
			_cyl(_st(parts, "wood"), Vector3(0, -0.12, 0), Vector3(0, 0.55, 0), 0.017, 0.015, 8)
			_box(_st(parts, "iron"), Vector3(0, 0.5, 0), Vector3(0.42, 0.035, 0.035))
		Kind.HAMMER:
			_cyl(_st(parts, "wood"), Vector3(0, -0.1, 0), Vector3(0, 0.34, 0), 0.015, 0.014, 8)
			_box(_st(parts, "iron"), Vector3(0, 0.34, 0), Vector3(0.14, 0.06, 0.06))
		Kind.SICKLE:
			_cyl(_st(parts, "wood"), Vector3(0, -0.06, 0), Vector3(0, 0.1, 0), 0.016, 0.016, 8)
			var arc := _st(parts, "steel")
			for i in 8:
				var a0 := PI * 0.5 + i * 0.35
				var a1 := a0 + 0.35
				var c := Vector3(0.12, 0.12, 0)
				_box_between(arc, c + Vector3(cos(a0), sin(a0), 0) * 0.14, c + Vector3(cos(a1), sin(a1), 0) * 0.14, 0.02, 0.004)
		Kind.CROSSBOW:
			_box(_st(parts, "wood"), Vector3(0, 0.18, 0), Vector3(0.05, 0.62, 0.06))
			_box(_st(parts, "wood"), Vector3(0, -0.1, -0.03), Vector3(0.045, 0.2, 0.1))
			var prod := _st(parts, "iron")
			_box_between(prod, Vector3(0, 0.46, 0), Vector3(-0.3, 0.4, 0), 0.022, 0.022)
			_box_between(prod, Vector3(0, 0.46, 0), Vector3(0.3, 0.4, 0), 0.022, 0.022)
			var string := _st(parts, "string")
			_box_between(string, Vector3(-0.3, 0.4, 0.0), Vector3(0, 0.3, 0.0), 0.004, 0.004)
			_box_between(string, Vector3(0.3, 0.4, 0.0), Vector3(0, 0.3, 0.0), 0.004, 0.004)
		Kind.STAFF:
			_cyl(_st(parts, "wood"), Vector3(0, -0.85, 0), Vector3(0, 0.9, 0), 0.02, 0.024, 8)
			_sphere(_st(parts, "wood"), Vector3(0, 0.93, 0), 0.05)
			_sphere(_st(parts, "crystal"), Vector3(0, 1.02, 0), 0.045)
	var mesh := ArrayMesh.new()
	for mat_name in parts:
		var st: SurfaceTool = parts[mat_name]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat_name))
	_cache[k] = mesh
	return mesh


static func _material(mat_name: String) -> Material:
	if _mats.has(mat_name):
		return _mats[mat_name]
	var m := StandardMaterial3D.new()
	# Hand-built geometry: draw both sides rather than trust every winding.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match mat_name:
		"steel":
			m.albedo_color = Color(0.82, 0.83, 0.85)
			m.metallic = 0.6
			m.roughness = 0.32
		"iron":
			m.albedo_color = Color(0.3, 0.29, 0.28)
			m.metallic = 0.85
			m.roughness = 0.5
		"leather":
			m.albedo_color = Color(0.25, 0.14, 0.08)
			m.roughness = 0.8
		"wood", "shield_wood":
			m.albedo_texture = load("res://art/third_party/ambientcg/Wood060/Wood060_Color.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://art/third_party/ambientcg/Wood060/Wood060_NormalGL.jpg")
			m.roughness = 0.75
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * (1.5 if mat_name == "shield_wood" else 4.0)
			if mat_name == "shield_wood":
				# Weathered planks with a faded red paint wash: the boards
				# read clearly even at a distance.
				m.albedo_texture = load("res://art/third_party/polyhaven/tex/weathered_planks_diff.jpg")
				m.normal_texture = load("res://art/third_party/polyhaven/tex/weathered_planks_nor_gl.jpg")
				m.albedo_color = Color(1.35, 0.78, 0.6)
				m.uv1_scale = Vector3.ONE * 1.4
		"rust":
			m.albedo_color = Color(0.36, 0.24, 0.16)
			m.metallic = 0.4
			m.roughness = 0.85
		"grave_wood":
			m.albedo_texture = load("res://art/third_party/ambientcg/Wood060/Wood060_Color.jpg")
			m.albedo_color = Color(0.35, 0.33, 0.28)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 1.5
			m.roughness = 0.95
		"string":
			m.albedo_color = Color(0.8, 0.75, 0.62)
			m.roughness = 0.9
		"crystal":
			m.albedo_color = Color(0.45, 0.75, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.3, 0.6, 1.0)
			m.emission_energy_multiplier = 2.5
			m.roughness = 0.1
	_mats[mat_name] = m
	return m


static func _st(parts: Dictionary, mat_name: String) -> SurfaceTool:
	if not parts.has(mat_name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[mat_name] = st
	return parts[mat_name]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Wound so the face looks along its geometric normal (Godot: clockwise front).
	var n := (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _box(st: SurfaceTool, c: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var p := func(x, y, z): return c + Vector3(h.x * x, h.y * y, h.z * z)
	_quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1))
	_quad(st, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1))
	_quad(st, p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1))
	_quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1))
	_quad(st, p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1))
	_quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1))


static func _box_between(st: SurfaceTool, a: Vector3, b: Vector3, w: float, t: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.BACK if absf(dir.z) < 0.9 else Vector3.UP).normalized() * w * 0.5
	var up := dir.cross(side).normalized() * t * 0.5
	var q := [a - side - up, a + side - up, a + side + up, a - side + up]
	var r := [b - side - up, b + side - up, b + side + up, b - side + up]
	for i in 4:
		_quad(st, q[i], q[(i + 1) % 4], r[(i + 1) % 4], r[i])
	_quad(st, q[3], q[2], q[1], q[0])
	_quad(st, r[0], r[1], r[2], r[3])


static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_quad(st, a + d1 * ra, a + d0 * ra, b + d0 * rb, b + d1 * rb)
		_tri(st, b, b + d1 * rb, b + d0 * rb)
		_tri(st, a, a + d0 * ra, a + d1 * ra)


static func _sphere(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings := 6
	var segs := 10
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var p0 := TAU * j / segs
			var p1 := TAU * (j + 1) / segs
			var v := func(t, p): return c + Vector3(sin(t) * cos(p), cos(t), sin(t) * sin(p)) * r
			_quad(st, v.call(t0, p1), v.call(t0, p0), v.call(t1, p0), v.call(t1, p1))


static func _disc(st: SurfaceTool, c: Vector3, r: float, thick: float, sides: int) -> void:
	var f := c + Vector3(0, 0, thick * 0.5)
	var bk := c - Vector3(0, 0, thick * 0.5)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), sin(a0), 0) * r
		var d1 := Vector3(cos(a1), sin(a1), 0) * r
		_tri(st, f, f + d0, f + d1)
		_tri(st, bk, bk + d1, bk + d0)
		_quad(st, f + d1, f + d0, bk + d0, bk + d1)


static func _ring(st: SurfaceTool, c: Vector3, r: float, w: float, depth: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		var zf := Vector3(0, 0, depth * 0.5)
		_quad(st, c + d1 * (r + w * 0.3) + zf, c + d0 * (r + w * 0.3) + zf, c + d0 * (r + w * 0.3) - zf, c + d1 * (r + w * 0.3) - zf)
		_quad(st, c + d0 * (r - w) + zf, c + d0 * (r + w * 0.3) + zf, c + d1 * (r + w * 0.3) + zf, c + d1 * (r - w) + zf)


## Double-edged blade from y0 to y1 with a diamond cross-section.
static func _blade(st: SurfaceTool, y0: float, y1: float, width: float, thick: float) -> void:
	var steps := 6
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var w0 := lerpf(width, width * 0.7, t0) * (1.0 if t0 < 0.85 else (1.0 - t0) / 0.15)
		var w1 := lerpf(width, width * 0.7, t1) * (1.0 if t1 < 0.85 else maxf(1.0 - t1, 0.0) / 0.15)
		var ya := lerpf(y0, y1, t0)
		var yb := lerpf(y0, y1, t1)
		var ea := [Vector3(-w0 * 0.5, ya, 0), Vector3(0, ya, thick * 0.5), Vector3(w0 * 0.5, ya, 0), Vector3(0, ya, -thick * 0.5)]
		var eb := [Vector3(-w1 * 0.5, yb, 0), Vector3(0, yb, thick * 0.5), Vector3(w1 * 0.5, yb, 0), Vector3(0, yb, -thick * 0.5)]
		for k in 4:
			_quad(st, ea[(k + 1) % 4], ea[k], eb[k], eb[(k + 1) % 4])


## Axe head: a wedge sticking out along +X from the haft at `c`.
static func _wedge(st: SurfaceTool, c: Vector3, length: float, height: float, thick: float) -> void:
	var back := [c + Vector3(-0.02, -0.03, -thick * 0.5), c + Vector3(-0.02, 0.03, -thick * 0.5), c + Vector3(-0.02, 0.03, thick * 0.5), c + Vector3(-0.02, -0.03, thick * 0.5)]
	var edge_top := c + Vector3(length, height * 0.5, 0)
	var edge_bot := c + Vector3(length, -height * 0.5, 0)
	_quad(st, back[0], back[1], edge_top, edge_bot)
	_quad(st, back[2], back[3], edge_bot, edge_top)
	_tri(st, back[1], back[2], edge_top)
	_tri(st, back[3], back[0], edge_bot)
	_quad(st, back[3], back[2], back[1], back[0])
