@tool
class_name PropModel
extends MeshInstance3D
## Realistic-scale props built in code with photographic CC0 wood/cloth
## textures (triplanar): barrels, sacks, a rowing boat, pier sections,
## benches and log piles. Origin at the base, front toward +Z.

enum Kind { BARREL, SACK, ROWBOAT, PIER, BENCH, LOG_PILE, BARREL_LYING, POST, PALLET, BUCKET, CRATE, LOG_BUNDLE, STONE_WALL }

@export var kind := Kind.BARREL:
	set(v):
		kind = v
		if is_inside_tree():
			mesh = build(v)
## Pier length in metres (PIER only).
@export var length := 6.0:
	set(v):
		length = v
		if is_inside_tree() and kind == Kind.PIER:
			mesh = build(kind, length)

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}

const WOOD := "res://art/third_party/ambientcg/Wood060/Wood060_"
const PLANKS := "res://art/third_party/ambientcg/WoodFloor041/WoodFloor041_"
const WEATHERED := "res://art/third_party/polyhaven/wood_"


func _ready() -> void:
	mesh = build(kind, length)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func build(k: Kind, len := 6.0) -> ArrayMesh:
	var key := "%d_%.1f" % [k, len if k == Kind.PIER else 0.0]
	if _cache.has(key):
		return _cache[key]
	# Barrels are the Poly Haven scanned oak wine barrel.
	if k == Kind.BARREL or k == Kind.BARREL_LYING:
		var rot := Transform3D.IDENTITY if k == Kind.BARREL else Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		var box := rot * PHModels.bounds("wine_barrel_01")
		rot.origin = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		_cache[key] = PHModels.mesh("wine_barrel_01", PackedStringArray(), rot)
		return _cache[key]
	var parts := {}
	match k:
		Kind.BARREL:
			_barrel(parts, Transform3D.IDENTITY)
		Kind.BARREL_LYING:
			_barrel(parts, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3, 0.42)))
		Kind.SACK:
			_sack(_st(parts, "cloth"))
		Kind.ROWBOAT:
			_boat(parts)
		Kind.PIER:
			_pier(parts, len)
		Kind.BENCH:
			WeaponModel._box(_st(parts, "planks"), Vector3(0, 0.44, 0), Vector3(1.6, 0.06, 0.34))
			for x in [-0.65, 0.65]:
				WeaponModel._box(_st(parts, "wood"), Vector3(x, 0.21, 0), Vector3(0.07, 0.42, 0.3))
		Kind.LOG_PILE:
			var st := _st(parts, "bark")
			var rows := [[-0.36, 0.0, 0.18], [0.0, 0.0, 0.18], [0.36, 0.0, 0.18], [-0.18, 0.31, 0.17], [0.18, 0.31, 0.17], [0.0, 0.6, 0.16]]
			for r in rows:
				_log(st, Vector3(r[0], r[1] + r[2], 0), 2.0, r[2])
		Kind.STONE_WALL:
			# A 2.1 m dry-stone wall section with a ragged, capped top.
			var sw := _st(parts, "drystone")
			var n := 8
			for i in n:
				var x0 := -1.05 + 2.1 * i / n
				var x1 := -1.05 + 2.1 * (i + 1) / n
				var h0 := 0.8 + sin(x0 * 5.3) * 0.06
				var h1 := 0.8 + sin(x1 * 5.3) * 0.06
				var w0 := 0.3 - (0.02 if i % 2 == 0 else 0.0)
				var q := [Vector3(x0, 0, w0), Vector3(x1, 0, w0), Vector3(x1, h1, w0 * 0.8), Vector3(x0, h0, w0 * 0.8)]
				WeaponModel._quad(sw, q[0], q[1], q[2], q[3])
				var r := [Vector3(x1, 0, -w0), Vector3(x0, 0, -w0), Vector3(x0, h0, -w0 * 0.8), Vector3(x1, h1, -w0 * 0.8)]
				WeaponModel._quad(sw, r[0], r[1], r[2], r[3])
				WeaponModel._quad(sw, Vector3(x0, h0, w0 * 0.8), Vector3(x1, h1, w0 * 0.8), Vector3(x1, h1, -w0 * 0.8), Vector3(x0, h0, -w0 * 0.8))
			var cap := _st(parts, "capstone")
			for i in 7:
				var x := -0.9 + i * 0.3
				WeaponModel._box(cap, Vector3(x, 0.84 + sin(x * 5.3) * 0.06, 0), Vector3(0.28, 0.1 + (i % 2) * 0.03, 0.5))
		Kind.LOG_BUNDLE:
			var lb := _st(parts, "bark")
			for r in [[-0.17, 0.0, 0.12], [0.07, 0.0, 0.13], [-0.05, 0.2, 0.11]]:
				_log(lb, Vector3(r[0], r[1] + r[2], 0), 1.4, r[2])
		Kind.PALLET:
			var pl := _st(parts, "planks")
			for i in 5:
				WeaponModel._box(pl, Vector3(-0.48 + i * 0.24, 0.13, 0), Vector3(0.18, 0.025, 1.0))
			var bearers := _st(parts, "wood_dark")
			for z in [-0.42, 0.0, 0.42]:
				WeaponModel._box(bearers, Vector3(0, 0.06, z), Vector3(1.2, 0.1, 0.1))
		Kind.BUCKET:
			var bst := _st(parts, "staves")
			for j in 14:
				var a0 := TAU * j / 14.0
				var a1 := TAU * (j + 1) / 14.0
				WeaponModel._quad(bst, Vector3(cos(a1) * 0.15, 0, sin(a1) * 0.15), Vector3(cos(a0) * 0.15, 0, sin(a0) * 0.15), Vector3(cos(a0) * 0.18, 0.3, sin(a0) * 0.18), Vector3(cos(a1) * 0.18, 0.3, sin(a1) * 0.18))
			var water := _st(parts, "water")
			for j in 14:
				var a0 := TAU * j / 14.0
				var a1 := TAU * (j + 1) / 14.0
				WeaponModel._tri(water, Vector3(0, 0.25, 0), Vector3(cos(a0) * 0.17, 0.25, sin(a0) * 0.17), Vector3(cos(a1) * 0.17, 0.25, sin(a1) * 0.17))
			var band := _st(parts, "iron")
			WeaponModel._cyl(band, Vector3(0, 0.05, 0), Vector3(0, 0.08, 0), 0.157, 0.16, 14)
			WeaponModel._cyl(band, Vector3(0, 0.22, 0), Vector3(0, 0.25, 0), 0.172, 0.175, 14)
		Kind.CRATE:
			var cst := _st(parts, "planks")
			WeaponModel._box(cst, Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6))
			var trim := _st(parts, "wood_dark")
			for y in [0.03, 0.57]:
				for z in [-0.29, 0.29]:
					WeaponModel._box(trim, Vector3(0, y, z), Vector3(0.64, 0.07, 0.04))
				for x in [-0.29, 0.29]:
					WeaponModel._box(trim, Vector3(x, y, 0), Vector3(0.04, 0.07, 0.64))
			for x in [-0.29, 0.29]:
				for z in [-0.29, 0.29]:
					WeaponModel._box(trim, Vector3(x, 0.3, z), Vector3(0.07, 0.6, 0.07))
		Kind.POST:
			WeaponModel._cyl(_st(parts, "wood_dark"), Vector3(0, -0.5, 0), Vector3(0, 1.4, 0), 0.12, 0.11, 10)
	var mesh := ArrayMesh.new()
	for mat_name in parts:
		var st: SurfaceTool = parts[mat_name]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat_name))
	_cache[key] = mesh
	return mesh


static func _material(mat_name: String) -> Material:
	if _mats.has(mat_name):
		return _mats[mat_name]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match mat_name:
		"wood", "wood_dark":
			m.albedo_texture = load(WOOD + "Color.jpg")
			m.normal_enabled = true
			m.normal_texture = load(WOOD + "NormalGL.jpg")
			m.roughness = 0.8
			m.uv1_scale = Vector3.ONE * 0.9
			if mat_name == "wood_dark":
				m.albedo_color = Color(0.55, 0.45, 0.38)
		"planks":
			m.albedo_texture = load(PLANKS + "Color.jpg")
			m.normal_enabled = true
			m.normal_texture = load(PLANKS + "NormalGL.jpg")
			m.roughness_texture = load(PLANKS + "Roughness.jpg")
			m.uv1_scale = Vector3.ONE * 0.45
			m.albedo_color = Color(1.05, 0.95, 0.85)
		"staves":
			m.albedo_texture = load(WEATHERED + "diff.jpg")
			m.normal_enabled = true
			m.normal_texture = load(WEATHERED + "nor.jpg")
			m.roughness = 0.75
			m.uv1_scale = Vector3.ONE * 1.4
			m.albedo_color = Color(0.85, 0.7, 0.55)
		"iron":
			m.albedo_color = Color(0.22, 0.2, 0.19)
			m.metallic = 0.8
			m.roughness = 0.55
			m.uv1_triplanar = false
		"cloth":
			m.albedo_texture = load("res://art/third_party/polyhaven/cloth2_diff.jpg") if ResourceLoader.exists("res://art/third_party/polyhaven/cloth2_diff.jpg") else null
			m.albedo_color = Color(0.86, 0.76, 0.6)
			m.roughness = 0.95
			m.uv1_scale = Vector3.ONE * 2.0
		"bark":
			m.albedo_texture = load("res://art/third_party/ambientcg/Bark001/Bark001_Color.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://art/third_party/ambientcg/Bark001/Bark001_NormalGL.jpg")
			m.albedo_color = Color(0.75, 0.65, 0.55)
			m.uv1_scale = Vector3.ONE * 1.5
		"water":
			m.albedo_color = Color(0.2, 0.3, 0.3)
			m.roughness = 0.05
			m.uv1_triplanar = false
		"drystone":
			m.albedo_texture = load("res://art/third_party/polyhaven/ground_diff.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://art/third_party/polyhaven/ground_nor.jpg")
			m.albedo_color = Color(1.05, 1.0, 0.92)
			m.uv1_scale = Vector3.ONE * 0.9
			m.roughness = 0.95
		"capstone":
			m.albedo_texture = load("res://art/third_party/ambientcg/Rock030/Rock030_Color.jpg")
			m.albedo_color = Color(1.4, 1.35, 1.25)
			m.uv1_scale = Vector3.ONE * 1.4
			m.roughness = 0.95
		"endgrain":
			m.albedo_color = Color(0.72, 0.56, 0.36)
			m.roughness = 0.9
	_mats[mat_name] = m
	return m


static func _st(parts: Dictionary, mat_name: String) -> SurfaceTool:
	return WeaponModel._st(parts, mat_name)


static func _barrel(parts: Dictionary, xf: Transform3D) -> void:
	var st := _st(parts, "staves")
	var sides := 18
	var h := 0.9
	var rings := 8
	var prof := func(t: float) -> float: return 0.27 + 0.06 * sin(t * PI)
	for i in rings:
		var t0 := float(i) / rings
		var t1 := float(i + 1) / rings
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var p := func(t, a): return xf * Vector3(cos(a) * prof.call(t), t * h, sin(a) * prof.call(t))
			WeaponModel._quad(st, p.call(t0, a1), p.call(t0, a0), p.call(t1, a0), p.call(t1, a1))
	var lid := _st(parts, "endgrain")
	for j in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		for y in [0.04, h - 0.02]:
			var r := 0.265
			WeaponModel._tri(lid, xf * Vector3(0, y, 0), xf * Vector3(cos(a0) * r, y, sin(a0) * r), xf * Vector3(cos(a1) * r, y, sin(a1) * r))
	var iron := _st(parts, "iron")
	for t: float in [0.1, 0.3, 0.7, 0.9]:
		var r: float = prof.call(t) + 0.006
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var y0 := t * h - 0.025
			var y1 := t * h + 0.025
			WeaponModel._quad(iron, xf * Vector3(cos(a1) * r, y0, sin(a1) * r), xf * Vector3(cos(a0) * r, y0, sin(a0) * r), xf * Vector3(cos(a0) * r, y1, sin(a0) * r), xf * Vector3(cos(a1) * r, y1, sin(a1) * r))


static func _sack(st: SurfaceTool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 2.0
	var rings := 8
	var segs := 12
	var prof := func(t: float) -> float:
		# Slumped sack: wide belly, pinched tied neck.
		return 0.3 * sin(pow(t, 0.8) * PI * 0.92) + 0.03
	for i in rings:
		var t0 := float(i) / rings
		var t1 := float(i + 1) / rings
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var p := func(t, a):
				var r: float = prof.call(t) * (1.0 + noise.get_noise_2d(a * 3.0, t * 4.0) * 0.18)
				return Vector3(cos(a) * r * 1.15, t * 0.62, sin(a) * r * 0.85)
			WeaponModel._quad(st, p.call(t0, a1), p.call(t0, a0), p.call(t1, a0), p.call(t1, a1))


static func _log(st: SurfaceTool, c: Vector3, len: float, r: float) -> void:
	var sides := 10
	for j in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var d0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var d1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		var f := Vector3(0, 0, len * 0.5)
		WeaponModel._quad(st, c + d1 - f, c + d0 - f, c + d0 + f, c + d1 + f)
		WeaponModel._tri(st, c + f, c + d0 + f, c + d1 + f)
		WeaponModel._tri(st, c - f, c + d1 - f, c + d0 - f)


## A clinker rowing boat ~4.2 m long, bow toward +Z.
static func _boat(parts: Dictionary) -> void:
	var hull := _st(parts, "planks")
	var steps := 14
	var cols := 8
	var L := 4.2
	var W := 0.72
	var D := 0.55
	var section := func(t: float, u: float) -> Vector3:
		# t along the hull (0 stern .. 1 bow), u across (-1..1).
		var z := (t - 0.5) * L
		var bow := clampf((t - 0.75) / 0.25, 0.0, 1.0)
		var stern := clampf((0.12 - t) / 0.12, 0.0, 1.0)
		var w := W * (1.0 - bow * bow * 0.95) * (1.0 - stern * 0.35)
		var depth := D * (1.0 - bow * 0.35) * (1.0 - stern * 0.2)
		var sheer := 0.62 + bow * bow * 0.22 + stern * 0.08
		var x := u * w
		var y := sheer - depth * (1.0 - u * u) - (0.0 if absf(u) < 1.0 else 0.0)
		return Vector3(x, y, z)
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		for j in cols:
			var u0 := -1.0 + 2.0 * j / cols
			var u1 := -1.0 + 2.0 * (j + 1) / cols
			WeaponModel._quad(hull, section.call(t0, u1), section.call(t0, u0), section.call(t1, u0), section.call(t1, u1))
	# Transom and thwarts.
	var wood := _st(parts, "wood_dark")
	for z in [-0.6, 0.4]:
		WeaponModel._box(wood, Vector3(0, 0.45, z), Vector3(1.2, 0.05, 0.24))
	var gun := _st(parts, "wood")
	for side in [-1.0, 1.0]:
		for i in steps:
			var a: Vector3 = section.call(float(i) / steps, side)
			var b: Vector3 = section.call(float(i + 1) / steps, side)
			WeaponModel._box_between(gun, a + Vector3(0, 0.02, 0), b + Vector3(0, 0.02, 0), 0.06, 0.05)
	# Oars resting across the thwarts.
	WeaponModel._box_between(gun, Vector3(-0.2, 0.52, -1.3), Vector3(0.3, 0.52, 1.2), 0.05, 0.05)


## A pier section: plank deck on posts, running along +Z for `len` metres.
static func _pier(parts: Dictionary, len: float) -> void:
	var deck := _st(parts, "planks")
	var width := 2.4
	var n := int(len / 0.3)
	for i in n:
		var z := -len * 0.5 + (i + 0.5) * len / n
		var jitter := sin(i * 12.9898) * 0.015
		WeaponModel._box(deck, Vector3(0, 0.02 + jitter, z), Vector3(width, 0.06, len / n - 0.025))
	var posts := _st(parts, "wood_dark")
	for i in int(len / 2.0) + 1:
		var z := -len * 0.5 + i * len / maxi(int(len / 2.0), 1)
		for x in [-width * 0.5 + 0.1, width * 0.5 - 0.1]:
			WeaponModel._cyl(posts, Vector3(x, -2.0, z), Vector3(x, 0.35, z), 0.11, 0.1, 8)
	var beams := _st(parts, "wood")
	for x in [-width * 0.5 + 0.1, width * 0.5 - 0.1]:
		WeaponModel._box(beams, Vector3(x, -0.08, 0), Vector3(0.14, 0.14, len))
