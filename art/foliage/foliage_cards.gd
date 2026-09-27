class_name FoliageCards
## Photographic foliage built from alpha-cut cards (Poly Haven CC0 scans,
## see art/third_party/polyhaven/README.md): crossed-card grasses, ferns and
## flowers, and deciduous trees and shrubs whose crowns are clouds of
## leaf-cluster cards around a textured trunk and branches.
## Trees are built at unit height (scale 6–12 in the world); everything
## else is built in metres.

const VEG := "res://art/third_party/polyhaven/vegetation/"
const SHADER := preload("res://art/foliage/card_foliage.gdshader")
const BARK := "res://art/third_party/ambientcg/Bark001/Bark001_"

static var _cache: Dictionary = {}


static func card_material(texture: String, tint := Color.WHITE, wind := 0.12, translucency := 0.35) -> ShaderMaterial:
	var key := "mat_%s_%s_%.2f" % [texture, tint.to_html(), wind]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"albedo_tex", load(VEG + texture))
	m.set_shader_parameter(&"tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter(&"wind_strength", wind)
	m.set_shader_parameter(&"translucency", translucency)
	_cache[key] = m
	return m


static func bark_material(birch := false) -> StandardMaterial3D:
	var key := "bark_%s" % birch
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BARK + "Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(BARK + "NormalGL.jpg")
	m.roughness_texture = load(BARK + "Roughness.jpg")
	m.albedo_color = Color(1.35, 1.32, 1.25) if birch else Color(0.62, 0.52, 0.44)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	return st


## One quad: centre `c`, axes `right`/`up` (half extents), UV rect, sway at
## bottom/top, shade (AO) and a volume normal.
static func _card(st: SurfaceTool, c: Vector3, right: Vector3, up: Vector3, uv: Rect2,
		sway: Vector2, shade: float, vol: Vector3) -> void:
	var n := right.cross(up).normalized()
	var corners := [c - right - up, c + right - up, c + right + up, c - right + up]
	var uvs := [Vector2(uv.position.x, uv.end.y), uv.end, Vector2(uv.end.x, uv.position.y), uv.position]
	var sw := [sway.x, sway.x, sway.y, sway.y]
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_color(Color(sw[idx], shade, 0.0, 1.0))
		st.set_custom(0, Color(vol.x, vol.y, vol.z, 0.0))
		st.set_normal(n)
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])


## A crossed-card plant (grass tuft, fern, flower): `planes` vertical
## cards through the origin, `size` = (width, height) in metres.
static func plant(texture: String, size: Vector2, planes := 3, tint := Color.WHITE, wind := 0.12) -> ArrayMesh:
	var key := "plant_%s_%s_%d_%s" % [texture, size, planes, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	for i in planes:
		var a := PI * i / planes + 0.3
		var right := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		var up := Vector3.UP * size.y * 0.5
		_card(st, Vector3(0, size.y * 0.5, 0), right, up, Rect2(0, 0, 1, 1), Vector2(0, 1), 1.0, Vector3.UP)
	var mesh := st.commit()
	mesh.surface_set_material(0, card_material(texture, tint, wind))
	_cache[key] = mesh
	return mesh


## Deciduous tree at unit height. variant 0/1 = broad crown, 2 = birch
## (slender white trunk, narrow airy crown).
static func tree(variant: int) -> ArrayMesh:
	var key := "tree_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + variant * 17
	var birch := variant == 2
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := _begin()
	var crown_c := Vector3(0, 0.66 if not birch else 0.7, 0)
	var crown_r := Vector3(0.3, 0.27, 0.3) if not birch else Vector3(0.19, 0.3, 0.19)
	# Trunk: gently leaning and tapering, bark UVs wrapped in metres/10.
	var trunk_top := Vector3(rng.randf_range(-0.03, 0.03), crown_c.y + 0.05, rng.randf_range(-0.03, 0.03))
	var r0 := 0.035 if not birch else 0.022
	_limb(wood, Vector3.ZERO, trunk_top, r0, r0 * 0.45, 8, 6)
	# The crown is a few overlapping lobes, each fed by a main branch.
	var lobes: Array[Vector4] = []  # xyz centre, w radius
	var lobe_count := rng.randi_range(4, 6) if not birch else rng.randi_range(3, 4)
	for l in lobe_count:
		var a := TAU * l / lobe_count + rng.randf_range(-0.4, 0.4)
		var spread := crown_r.x * rng.randf_range(0.35, 0.7)
		var c := crown_c + Vector3(cos(a) * spread, rng.randf_range(-0.6, 0.7) * crown_r.y, sin(a) * spread)
		lobes.append(Vector4(c.x, c.y, c.z, crown_r.x * rng.randf_range(0.5, 0.7)))
	lobes.append(Vector4(crown_c.x, crown_c.y + crown_r.y * 0.45, crown_c.z, crown_r.x * 0.55))
	for lobe in lobes:
		var start := Vector3.ZERO.lerp(trunk_top, rng.randf_range(0.5, 0.9))
		var end := Vector3(lobe.x, lobe.y, lobe.z)
		var mid := start.lerp(end, 0.5) + Vector3(rng.randf_range(-0.03, 0.03), 0.03, rng.randf_range(-0.03, 0.03))
		_limb(wood, start, mid, r0 * 0.5, r0 * 0.3, 5, 2)
		_limb(wood, mid, end, r0 * 0.3, r0 * 0.1, 5, 2)
	# Leaf-cluster cards on each lobe: an outer shell (lit), a sparser
	# interior (dark).
	var per_lobe := (160 if not birch else 100) / lobes.size()
	for lobe in lobes:
		var lc := Vector3(lobe.x, lobe.y, lobe.z)
		for i in per_lobe:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
			var depth := pow(rng.randf(), 0.4)
			var p := lc + dir * lobe.w * depth * Vector3(1.0, 0.85, 1.0)
			var size := rng.randf_range(0.08, 0.12) * (0.8 if birch else 1.0)
			var normal := (dir * 0.7 + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.2, 0.8), rng.randf_range(-0.7, 0.7))).normalized()
			var right := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
			var up := right.cross(normal).normalized()
			var roll := rng.randf() * TAU
			var q := rng.randi() % 4
			var uv := Rect2(Vector2(q % 2, q / 2) * 0.5, Vector2(0.5, 0.5))
			var outer := (p - crown_c).length() / (crown_r.x * 1.3)
			var shade := clampf(depth * 0.6 + outer * 0.4 + dir.y * 0.15, 0.0, 1.0)
			_card(leaves, p, right.rotated(normal, roll) * size, up.rotated(normal, roll) * size, uv,
				Vector2(0.4 + depth * 0.4, 0.6 + depth * 0.4), shade, ((p - crown_c) + (p - lc) * 0.8).normalized())
	var mesh := wood.commit()
	mesh.surface_set_material(0, bark_material(birch))
	leaves.commit(mesh)
	var tint := Color(1.0, 1.02, 0.9) if variant == 0 else (Color(0.85, 0.95, 0.75) if variant == 1 else Color(1.1, 1.08, 0.82))
	var lm := card_material("broadleaf_foliage.png", tint, 0.02, 0.4).duplicate() as ShaderMaterial
	lm.set_shader_parameter(&"wind_strength", 0.012)
	lm.set_shader_parameter(&"volume_normals", 0.85)
	mesh.surface_set_material(1, lm)
	_cache[key] = mesh
	return mesh


## A round shrub (~1 m) from leaf-cluster cards, in metres.
static func shrub(variant: int) -> ArrayMesh:
	var key := "shrub_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var st := _begin()
	var c := Vector3(0, 0.45, 0)
	var r := Vector3(0.62, 0.48, 0.62)
	for i in 34:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		var depth := pow(rng.randf(), 0.4)
		var p := c + dir * r * depth
		p.y = maxf(p.y, 0.12)
		var size := rng.randf_range(0.26, 0.38)
		var normal := (dir + Vector3(rng.randf_range(-0.5, 0.5), 0.3, rng.randf_range(-0.5, 0.5))).normalized()
		var right := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := right.cross(normal).normalized()
		var roll := rng.randf() * TAU
		var q := rng.randi() % 4
		_card(st, p, right.rotated(normal, roll) * size, up.rotated(normal, roll) * size,
			Rect2(Vector2(q % 2, q / 2) * 0.5, Vector2(0.5, 0.5)), Vector2(0.2, 0.5),
			clampf(depth + dir.y * 0.2, 0.0, 1.0), (p - c * 0.6).normalized())
	var mesh := st.commit()
	var tint := [Color(1.1, 1.25, 0.85), Color(1.0, 1.18, 0.8), Color(1.2, 1.25, 0.8)][variant % 3] as Color
	var m := card_material("broadleaf_foliage.png", tint, 0.05).duplicate() as ShaderMaterial
	m.set_shader_parameter(&"volume_normals", 0.8)
	m.set_shader_parameter(&"brightness", 1.15)
	mesh.surface_set_material(0, m)
	_cache[key] = mesh
	return mesh


## Tapered bark cylinder between two points.
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, rings: int) -> void:
	var axis := (b - a)
	var dir := axis.normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := dir.cross(side)
	var length := axis.length()
	for r in rings:
		var t0 := float(r) / rings
		var t1 := float(r + 1) / rings
		var c0 := a + axis * t0
		var c1 := a + axis * t1
		var rad0 := lerpf(ra, rb, t0)
		var rad1 := lerpf(ra, rb, t1)
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := side * cos(a0) + fwd * sin(a0)
			var d1 := side * cos(a1) + fwd * sin(a1)
			var pts := [[c0 + d0 * rad0, d0, Vector2(float(i) / sides, t0 * length * 4.0)],
				[c0 + d1 * rad0, d1, Vector2(float(i + 1) / sides, t0 * length * 4.0)],
				[c1 + d1 * rad1, d1, Vector2(float(i + 1) / sides, t1 * length * 4.0)],
				[c1 + d0 * rad1, d0, Vector2(float(i) / sides, t1 * length * 4.0)]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(pts[idx][1])
				st.set_uv(pts[idx][2])
				st.add_vertex(pts[idx][0])
