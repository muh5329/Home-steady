class_name TerraceHills
extends Node3D
## Stacked, terraced red-clay hills (the Fabledom silhouette), generated at
## load from a list of placements. Each hill is a few irregular rings
## stacked like a layer cake: clay walls with grassy tops, plus a solid
## collider so the land's edge is a wall, not a drop.

## Each entry: x, z, base radius (m), terraces.
@export var hills: Array[Vector4] = []
@export var terrace_height := 3.2
@export var shrink_per_terrace := 0.8
@export var irregularity := 0.22
@export var segments := 40
@export var side_material: Material
@export var top_material: Material
@export var random_seed := 7

const GROUP := &"terrace_hills"

## Summit plateaus (x, top y, z, radius) for scenery to dress (pines).
var tops: Array[Vector4] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = random_seed
	for h in hills:
		_build_hill(Vector3(h.x, 0, h.y), h.z, int(h.w))


func _build_hill(centre: Vector3, radius: float, terraces: int) -> void:
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var phase := _rng.randf() * TAU
	var phase2 := _rng.randf() * TAU
	var base_ring: PackedVector2Array
	var y0 := 0.0
	# Each terrace sits off-centre on the one below and has its own height,
	# so hills read as heaped mounds, not stacked cakes.
	var drift := Vector2.ZERO
	for k in terraces:
		var r := radius * pow(shrink_per_terrace, k) * _rng.randf_range(0.9, 1.08)
		var h := terrace_height * _rng.randf_range(0.6, 1.4)
		if k > 0:
			drift += Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * r * 0.12
		var ring := PackedVector2Array()
		var ring_y := PackedFloat32Array()
		for i in segments:
			var a := TAU * i / segments
			var wobble := 1.0 + irregularity * (sin(a * 3.0 + phase + k) * 0.6 + sin(a * 7.0 + phase2 - k) * 0.4)
			ring.append(drift + Vector2(cos(a), sin(a)) * r * wobble)
			# The rim rises and dips a little around the hill.
			ring_y.append(h * (1.0 + 0.18 * sin(a * 2.0 + phase2 + k * 1.7)))
		if k == 0:
			base_ring = ring
		_add_walls(side, ring, ring_y, y0 - (0.6 if k == 0 else 0.0), y0)
		_add_cap(top, ring, ring_y, y0, drift)
		if k == terraces - 1:
			tops.append(Vector4(centre.x + drift.x, y0 + h, centre.z + drift.y, r * 0.55))
		y0 += h * 0.9
	var mesh := side.commit()
	top.commit(mesh)
	mesh.surface_set_material(0, side_material)
	mesh.surface_set_material(1, top_material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = centre
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var poly := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in base_ring:
		pts.append(Vector3(p.x, -0.5, p.y))
		pts.append(Vector3(p.x * 0.8, terrace_height * terraces, p.y * 0.8))
	poly.points = pts
	shape.shape = poly
	body.add_child(shape)
	body.position = centre
	add_child(body)


func _add_walls(st: SurfaceTool, ring: PackedVector2Array, ring_y: PackedFloat32Array, foot: float, base: float) -> void:
	var n := ring.size()
	var around := 0.0
	var mid := Vector2.ZERO
	for p in ring:
		mid += p
	mid /= n
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		var seg := a.distance_to(b)
		var inset := 0.84  # walls slope in toward the top
		var a0 := Vector3(a.x, foot, a.y)
		var b0 := Vector3(b.x, foot, b.y)
		var ai := mid + (a - mid) * inset
		var bi := mid + (b - mid) * inset
		var a1 := Vector3(ai.x, base + ring_y[i], ai.y)
		var b1 := Vector3(bi.x, base + ring_y[(i + 1) % n], bi.y)
		var normal := (Vector3(a.x + b.x - 2.0 * mid.x, 0, a.y + b.y - 2.0 * mid.y).normalized() + Vector3.UP * 0.35).normalized()
		var u0 := around
		var u1 := around + seg
		# Clockwise seen from outside (Godot's front faces).
		for v in [[a0, Vector2(u0, 0)], [b1, Vector2(u1, 1)], [a1, Vector2(u0, 1)],
				[a0, Vector2(u0, 0)], [b0, Vector2(u1, 0)], [b1, Vector2(u1, 1)]]:
			st.set_normal(normal)
			st.set_uv(v[1])
			st.add_vertex(v[0])
		around = u1


## Grassy top with a rounded lip draped over the wall's edge.
func _add_cap(st: SurfaceTool, ring: PackedVector2Array, ring_y: PackedFloat32Array, base: float, mid: Vector2) -> void:
	var n := ring.size()
	var top_y := 0.0
	for v in ring_y:
		top_y += v
	top_y = base + top_y / n
	var c := Vector3(mid.x, top_y + 0.3, mid.y)
	for i in n:
		var j := (i + 1) % n
		var a := mid + (ring[i] - mid) * 0.84
		var b := mid + (ring[j] - mid) * 0.84
		var ya := base + ring_y[i]
		var yb := base + ring_y[j]
		var ai := Vector3(mid.x + (a.x - mid.x) * 0.8, ya + 0.15, mid.y + (a.y - mid.y) * 0.8)
		var bi := Vector3(mid.x + (b.x - mid.x) * 0.8, yb + 0.15, mid.y + (b.y - mid.y) * 0.8)
		var ao := Vector3(mid.x + (a.x - mid.x) * 1.06, ya - 0.45, mid.y + (a.y - mid.y) * 1.06)
		var bo := Vector3(mid.x + (b.x - mid.x) * 1.06, yb - 0.45, mid.y + (b.y - mid.y) * 1.06)
		var out := Vector3(a.x + b.x - 2.0 * mid.x, 0, a.y + b.y - 2.0 * mid.y).normalized()
		var lip := (Vector3.UP + out * 0.6).normalized()
		var drape := (Vector3.UP * 0.4 + out).normalized()
		# Clockwise seen from above/outside (Godot's front faces).
		for v in [[c, Vector3.UP], [ai, Vector3.UP], [bi, Vector3.UP],
				[ai, lip], [bo, drape], [bi, lip],
				[ai, lip], [ao, drape], [bo, drape]]:
			st.set_normal(v[1])
			st.set_uv(Vector2.ZERO)
			st.add_vertex(v[0])
