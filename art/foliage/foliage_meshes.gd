class_name FoliageMeshes
## Procedural stylized foliage meshes (built once, cached): grass clumps,
## wildflowers and layered pines. Vertex colours carry the painting; the
## foliage/grass shaders add wind and light.

const GRASS_SHADER := preload("res://art/foliage/grass.gdshader")
const FOLIAGE_SHADER := preload("res://art/foliage/foliage.gdshader")
const GROUND_NOISE := preload("res://art/environments/materials/stylized_ground.tres")

static var _cache: Dictionary = {}


static func grass_material() -> ShaderMaterial:
	if not _cache.has("grass_mat"):
		var m := ShaderMaterial.new()
		m.shader = GRASS_SHADER
		m.set_shader_parameter(&"noise_large", GROUND_NOISE.get_shader_parameter(&"noise_large"))
		_cache["grass_mat"] = m
	return _cache["grass_mat"]


static func foliage_material() -> ShaderMaterial:
	if not _cache.has("foliage_mat"):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE_SHADER
		_cache["foliage_mat"] = m
	return _cache["foliage_mat"]


## Foliage material for closed shapes (bushes, boulders): shaded inside.
static func solid_material() -> ShaderMaterial:
	if not _cache.has("solid_mat"):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE_SHADER
		m.set_shader_parameter(&"solid_interior", true)
		_cache["solid_mat"] = m
	return _cache["solid_mat"]


## Tilled earth: photographed mud, shaded by the ridge vertex colours.
static func soil_material() -> StandardMaterial3D:
	if not _cache.has("soil_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://art/third_party/polyhaven/mudfield_diff.jpg")
		m.normal_enabled = true
		m.normal_texture = load("res://art/third_party/polyhaven/mudfield_nor.jpg")
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(2.2, 2.3, 2.5)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.6
		m.roughness = 0.95
		_cache["soil_mat"] = m
	return _cache["soil_mat"]


## Photographed rock (ambientCG Rock030), wrapped with triplanar mapping.
static func rock_material() -> StandardMaterial3D:
	if not _cache.has("rock_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://art/third_party/ambientcg/Rock030/Rock030_Color.jpg")
		m.normal_enabled = true
		m.normal_texture = load("res://art/third_party/ambientcg/Rock030/Rock030_NormalGL.jpg")
		m.roughness_texture = load("res://art/third_party/ambientcg/Rock030/Rock030_Roughness.jpg")
		m.albedo_color = Color(1.45, 1.38, 1.25)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.7
		_cache["rock_mat"] = m
	return _cache["rock_mat"]


## A tuft of curved, tapered blades (~0.5 m tall).
static func grass_clump() -> ArrayMesh:
	if _cache.has("grass"):
		return _cache["grass"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for b in 18:
		var ang := rng.randf() * TAU
		var root := Vector3(rng.randf_range(-0.26, 0.26), 0, rng.randf_range(-0.26, 0.26))
		var h := rng.randf_range(0.16, 0.34)
		var w := rng.randf_range(0.05, 0.075)
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.08, 0.22)
		var side := Vector3(-sin(ang), 0, cos(ang)) * w
		var segs := 3
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var p0 := root + Vector3.UP * h * t0 + lean * t0 * t0
			var p1 := root + Vector3.UP * h * t1 + lean * t1 * t1
			var w0 := 1.0 - t0
			var w1 := 1.0 - t1 * 0.97
			var quad := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
			var alphas := [t0, t0, t1, t1]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(1, 1, 1, alphas[idx]))
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[idx])
	var mesh := st.commit()
	mesh.surface_set_material(0, grass_material())
	_cache["grass"] = mesh
	return mesh


## A little wildflower cluster: stems and five-petal heads in `petal`.
static func flower(petal: Color) -> ArrayMesh:
	var key := "flower_%s" % petal.to_html()
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var stem := Color(0.22, 0.42, 0.14, 0.6)
	var heart := Color(1.0, 0.82, 0.25, 1.0)
	for f in 4:
		var base := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
		var h := rng.randf_range(0.28, 0.5)
		var top := base + Vector3(rng.randf_range(-0.05, 0.05), h, rng.randf_range(-0.05, 0.05))
		_quad_between(st, base, top, 0.012, stem)
		var r := rng.randf_range(0.055, 0.085)
		var tint := petal.lightened(rng.randf_range(-0.05, 0.15))
		tint.a = 1.0
		for p in 5:
			var a := TAU * p / 5.0 + rng.randf()
			var dir := Vector3(cos(a), 0.25, sin(a))
			var c := top + dir * r
			var sidev := Vector3(-sin(a), 0, cos(a)) * r * 0.55
			for v in [top, c + sidev, c - sidev]:
				st.set_color(tint)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		for v in [top + Vector3(0.02, 0.01, 0), top + Vector3(-0.01, 0.01, 0.02), top + Vector3(-0.01, 0.01, -0.02)]:
			st.set_color(heart)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, foliage_material())
	_cache[key] = mesh
	return mesh


## A tall meadow tuft (~0.8 m): long arching blades and a few oat-like
## seed stalks. Lines roads and fences and fills the lushest drifts.
static func tall_grass() -> ArrayMesh:
	if _cache.has("tall_grass"):
		return _cache["tall_grass"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var root_col := Color(0.26, 0.46, 0.16)
	var tip_col := Color(0.7, 0.8, 0.36)
	var seed_col := Color(0.96, 0.84, 0.5)
	for b in 16:
		var ang := rng.randf() * TAU
		var root := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
		var h := rng.randf_range(0.45, 0.8)
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.12, 0.3)
		var side := Vector3(-sin(ang), 0, cos(ang)) * 0.04
		var tint := rng.randf_range(-0.05, 0.08)
		for sgm in 4:
			var t0 := float(sgm) / 4.0
			var t1 := float(sgm + 1) / 4.0
			var p0 := root + Vector3.UP * h * t0 + lean * t0 * t0
			var p1 := root + Vector3.UP * h * t1 + lean * t1 * t1
			var w0 := 1.0 - t0 * 0.9
			var w1 := 1.0 - t1 * 0.9
			var q := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
			var ts := [t0, t0, t1, t1]
			for idx in [0, 1, 2, 0, 2, 3]:
				var c := root_col.lerp(tip_col, ts[idx]).lightened(tint)
				c.a = ts[idx]
				st.set_color(c)
				st.set_normal((Vector3.UP + side.normalized() * 0.3).normalized())
				st.add_vertex(q[idx])
	for k in 5:
		var root := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		var top := root + Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.75, 1.0), rng.randf_range(-0.12, 0.12))
		_quad_between(st, root, top, 0.008, Color(0.5, 0.6, 0.28))
		# Seed head: small spikelets hanging along the top of the stalk.
		for j in 5:
			var at := top.lerp(root, j * 0.06)
			var dir := Vector3(cos(j * 2.4 + k), -0.6, sin(j * 2.4 + k)).normalized()
			var end := at + dir * 0.07
			var off := dir.cross(Vector3.UP).normalized() * 0.018
			for v in [at, end + off, end - off]:
				st.set_color(Color(seed_col.r, seed_col.g, seed_col.b, 1.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, foliage_material())
	_cache["tall_grass"] = mesh
	return mesh


## A bed of ripe wheat for one farm plot (~1.3 x 1.7 m): three rows of
## dense golden tufts, each blade green at the root and gold at the tip,
## crowned with plump ears.
static func wheat_bed() -> ArrayMesh:
	if _cache.has("wheat"):
		return _cache["wheat"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var root_col := Color(0.42, 0.5, 0.18)
	var tip_col := Color(0.86, 0.76, 0.46)
	var ear_col := Color(0.88, 0.74, 0.42)
	for row in 3:
		for k in 5:
			var centre := Vector3((row - 1) * 0.44 + rng.randf_range(-0.05, 0.05), 0, -0.7 + k * 0.35 + rng.randf_range(-0.06, 0.06))
			for b in 9:
				var ang := rng.randf() * TAU
				var root := centre + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
				var h := rng.randf_range(0.55, 0.85)
				var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.05, 0.16)
				var side := Vector3(-sin(ang), 0, cos(ang)) * 0.035
				var tint := rng.randf_range(-0.06, 0.06)
				for s in 3:
					var t0 := float(s) / 3.0
					var t1 := float(s + 1) / 3.0
					var p0 := root + Vector3.UP * h * t0 + lean * t0 * t0
					var p1 := root + Vector3.UP * h * t1 + lean * t1 * t1
					var w0 := 1.0 - t0 * 0.7
					var w1 := 1.0 - t1 * 0.7
					var q := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
					var ts := [t0, t0, t1, t1]
					for idx in [0, 1, 2, 0, 2, 3]:
						var c := root_col.lerp(tip_col, ts[idx]).lightened(tint)
						c.a = ts[idx] * 0.8
						st.set_color(c)
						st.set_normal((Vector3.UP + side.normalized() * 0.3).normalized())
						st.add_vertex(q[idx])
				if b % 2 == 0:
					# An ear: two crossed plump diamonds at the blade tip.
					var top := root + Vector3.UP * h + lean
					var dir := (Vector3.UP * 0.9 + lean * 1.5).normalized()
					var len := rng.randf_range(0.16, 0.22)
					var mid := top + dir * len * 0.45
					var tip := top + dir * len
					for axis in [Vector3.RIGHT, Vector3.FORWARD]:
						var off: Vector3 = dir.cross(axis).normalized() * 0.045
						var shade := 1.0 if axis == Vector3.RIGHT else 0.88
						var ec := Color(ear_col.r * shade, ear_col.g * shade, ear_col.b * shade, 0.85)
						for v in [top, mid + off, tip, top, tip, mid - off]:
							st.set_color(ec)
							st.set_normal((v - top + Vector3.UP * 0.1).normalized() if v != top else Vector3.UP)
							st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, foliage_material())
	_cache["wheat"] = mesh
	return mesh


## Raised soil ridges for a tilled field (`rows` ridges across `size`),
## vertex-painted dark in the troughs and warm on the crests.
static func furrows(size: Vector2, rows: int) -> ArrayMesh:
	var key := "furrows_%s_%d" % [size, rows]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trough := Color(0.3, 0.19, 0.12, 0.0)
	var crest := Color(0.55, 0.36, 0.22, 0.0)
	var pitch := size.x / rows
	var steps := 6
	for r in rows:
		for i in steps:
			var u0 := float(i) / steps
			var u1 := float(i + 1) / steps
			var x0 := -size.x * 0.5 + (r + u0) * pitch
			var x1 := -size.x * 0.5 + (r + u1) * pitch
			var y0 := sin(u0 * PI) * 0.12
			var y1 := sin(u1 * PI) * 0.12
			var n0 := Vector3(-cos(u0 * PI) * 0.6, 1, 0).normalized()
			var n1 := Vector3(-cos(u1 * PI) * 0.6, 1, 0).normalized()
			var c0 := trough.lerp(crest, sin(u0 * PI))
			var c1 := trough.lerp(crest, sin(u1 * PI))
			var z0 := -size.y * 0.5
			var z1 := size.y * 0.5
			var q := [[Vector3(x0, y0, z0), n0, c0], [Vector3(x1, y1, z0), n1, c1], [Vector3(x1, y1, z1), n1, c1], [Vector3(x0, y0, z1), n0, c0]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_color(q[idx][2])
				st.set_normal(q[idx][1])
				st.add_vertex(q[idx][0])
	var mesh := st.commit()
	mesh.surface_set_material(0, soil_material())
	_cache[key] = mesh
	return mesh


## A layered stylized pine (~1 unit tall before scaling; scale ~8-12).
## `variant` changes proportions and palette slightly.
static func pine(variant: int) -> ArrayMesh:
	var key := "pine_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.38, 0.24, 0.16, 0.0)
	_cylinder(st, Vector3.ZERO, 0.035, 0.022, 0.3, 7, trunk, trunk.darkened(0.2))
	var tiers := 5 + variant % 2
	var dark := Color(0.1, 0.27, 0.19).lerp(Color(0.12, 0.31, 0.16), rng.randf())
	var light := Color(0.28, 0.52, 0.29).lerp(Color(0.38, 0.58, 0.26), rng.randf())
	for t in tiers:
		var f := float(t) / tiers
		var y0 := 0.14 + f * 0.72
		var radius := lerpf(0.34, 0.09, f) * rng.randf_range(0.9, 1.1)
		var height := lerpf(0.26, 0.16, f)
		_skirt(st, y0, radius, height, 11, rng, dark.lerp(light, f * 0.6), light.lerp(Color(0.5, 0.66, 0.34), f * 0.5), f)
	var mesh := st.commit()
	mesh.surface_set_material(0, foliage_material())
	_cache[key] = mesh
	return mesh


## A leafy shrub (~1 m): a heap of lumpy leaf balls, dark inside and
## sunlit on top.
static func bush(variant: int) -> ArrayMesh:
	var key := "bush_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var noise := FastNoiseLite.new()
	noise.seed = 31 + variant
	noise.frequency = 2.2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.12, 0.3, 0.12).lerp(Color(0.16, 0.34, 0.1), rng.randf())
	var light := Color(0.42, 0.62, 0.22).lerp(Color(0.5, 0.64, 0.2), rng.randf())
	for lump in rng.randi_range(4, 6):
		var centre := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.3, 0.6), rng.randf_range(-0.35, 0.35))
		var radius := rng.randf_range(0.22, 0.55)
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 1.8
		sphere.radial_segments = 12
		sphere.rings = 7
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var moved := PackedVector3Array()
		for v in verts:
			moved.append(centre + v * (1.0 + noise.get_noise_3dv(v * 2.0 + Vector3(lump, 0, 0)) * 0.35))
		for t in range(0, idx.size(), 3):
			var a := moved[idx[t]]
			var b := moved[idx[t + 1]]
			var c := moved[idx[t + 2]]
			# Soft, rounded shading: each vertex's normal points out from the
			# clump's centre (lifted a little so tops catch the sun).
			for v: Vector3 in [a, b, c]:
				var n := ((v - centre).normalized() + Vector3.UP * 0.35).normalized()
				var up := clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
				var col := dark.lerp(light, up * up)
				col.a = 0.5
				st.set_color(col)
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, solid_material())
	_cache[key] = mesh
	return mesh


## A mossy boulder cluster (~0.85 m radius): lumpy displaced spheres,
## warm grey with moss on the upward faces.
static func boulder(variant: int) -> ArrayMesh:
	var key := "boulder_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + variant
	var noise := FastNoiseLite.new()
	noise.seed = 77 + variant
	noise.frequency = 1.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color(0.56, 0.53, 0.49)
	var moss := Color(0.36, 0.48, 0.2)
	for lump in 3:
		var centre := Vector3(rng.randf_range(-0.35, 0.35), 0.2, rng.randf_range(-0.35, 0.35)) if lump > 0 else Vector3(0, 0.3, 0)
		var radius := 0.6 if lump == 0 else rng.randf_range(0.3, 0.45)
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 1.6
		sphere.radial_segments = 10
		sphere.rings = 6
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var moved := PackedVector3Array()
		for v in verts:
			var n := v.normalized()
			var d := 1.0 + noise.get_noise_3dv(v * 1.3 + Vector3(lump, 0, 0)) * 0.28
			moved.append(centre + v * d)
		for t in range(0, idx.size(), 3):
			var a := moved[idx[t]]
			var b := moved[idx[t + 1]]
			var c := moved[idx[t + 2]]
			var normal := (c - a).cross(b - a).normalized()
			if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
				normal = -normal
			var up := clampf(normal.y, 0.0, 1.0)
			var shade := stone.lerp(stone.lightened(0.12), rng.randf())
			var col := shade.lerp(moss, smoothstep(0.55, 0.9, up))
			col.a = 0.0
			for v in [a, b, c]:
				st.set_color(col)
				st.set_normal(normal)
				st.add_vertex(v)
	# Smooth, rounded stone: merge vertices and average the normals.
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, rock_material())
	_cache[key] = mesh
	return mesh


# --- helpers --------------------------------------------------------------------------

## A drooping, jagged cone tier: dark underside, lighter sunlit top.
static func _skirt(st: SurfaceTool, y: float, r: float, h: float, points: int,
		rng: RandomNumberGenerator, under: Color, top_col: Color, sway: float) -> void:
	var apex := Vector3(0, y + h, 0)
	var rim: Array[Vector3] = []
	for i in points * 2:
		var a := TAU * i / (points * 2)
		var rr := r * (1.0 if i % 2 == 0 else 0.72) * rng.randf_range(0.9, 1.08)
		var droop := -0.04 if i % 2 == 0 else 0.0
		rim.append(Vector3(cos(a) * rr, y + droop, sin(a) * rr))
	var inner := Vector3(0, y + h * 0.15, 0)
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		var shade := 0.85 + 0.3 * (0.5 + 0.5 * cos(atan2(a.z, a.x) - 0.9))  # sun side lighter
		var c_top := Color(top_col.r * shade, top_col.g * shade, top_col.b * shade, 0.4 + sway)
		var c_rim := Color(under.r * 1.15 * shade, under.g * 1.15 * shade, under.b * 1.15 * shade, 0.4 + sway)
		# Smooth, cone-like shading: the apex faces up, each rim point faces
		# out from the trunk, so tiers read as soft boughs, not flat slabs.
		var na := (Vector3(a.x, 0, a.z).normalized() + Vector3.UP * 0.75).normalized()
		var nb := (Vector3(b.x, 0, b.z).normalized() + Vector3.UP * 0.75).normalized()
		for v in [[apex, c_top, Vector3.UP], [a, c_rim, na], [b, c_rim, nb]]:
			st.set_color(v[1])
			st.set_normal(v[2])
			st.add_vertex(v[0])
		var c_in := Color(under.r * 0.6, under.g * 0.6, under.b * 0.6, 0.4 + sway)
		for v in [[inner, c_in], [b, c_rim.darkened(0.3)], [a, c_rim.darkened(0.3)]]:
			st.set_color(v[1])
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v[0])


static func _cylinder(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, sides: int, c0: Color, c1: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var q := [base + d0 * r0, base + d1 * r0, base + d1 * r1 + Vector3.UP * h, base + d0 * r1 + Vector3.UP * h]
		var cols := [c1, c1, c0, c0]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(cols[idx])
			st.set_normal((d0 + d1).normalized())
			st.add_vertex(q[idx])


static func _quad_between(st: SurfaceTool, a: Vector3, b: Vector3, w: float, c: Color) -> void:
	var side := Vector3(w, 0, 0)
	var q := [a - side, a + side, b + side, b - side]
	var alphas := [0.0, 0.0, 1.0, 1.0]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(c.r, c.g, c.b, alphas[idx]))
		st.set_normal(Vector3.UP)
		st.add_vertex(q[idx])
