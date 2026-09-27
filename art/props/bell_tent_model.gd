extends MeshInstance3D
## A storybook bell tent built in code: striped canvas cone with a gentle
## sag, a scalloped valance, a dark doorway on +Z (under the eave) and a pennant on top.
## About 3 m across and 3 m tall at scale 1.

const SEGMENTS := 32
const CANVAS := Color(0.9, 0.86, 0.76)
const STRIPE := Color(0.6, 0.27, 0.19)
const DOOR := Color(0.23, 0.14, 0.09)
const POLE := Color(0.45, 0.3, 0.2)

## Radius and height of the rings from the ground to the apex.
const WALL_R := 1.5
const WALL_H := 0.85
const EAVE_R := 1.6
const APEX_H := 2.75

static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = _build()
	mesh = _mesh


static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Profile rings: ground, top of wall, eave (roof start), sagging mid, apex.
	var rings := [
		[WALL_R * 1.02, 0.0], [WALL_R, WALL_H], [EAVE_R, WALL_H + 0.02],
		[EAVE_R * 0.47, WALL_H + (APEX_H - WALL_H) * 0.52], [0.06, APEX_H],
	]
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var stripe := (i >> 1) % 2 == 1
		for r in rings.size() - 1:
			if r == 1:
				continue  # wall top to eave is a tiny step hidden by the valance
			var roof := r >= 2
			var col: Color = (STRIPE if stripe else CANVAS) if roof else CANVAS.darkened(0.06)
			_band(st, a0, a1, rings[r], rings[r + 1], col)
		# Valance: a scallop hanging under the eave.
		var mid := (a0 + a1) * 0.5
		var e0 := _ring_point(a0, EAVE_R + 0.01, WALL_H + 0.03)
		var e1 := _ring_point(a1, EAVE_R + 0.01, WALL_H + 0.03)
		var tip := _ring_point(mid, EAVE_R * 0.99, WALL_H - 0.2)
		_tri(st, e0, e1, tip, (STRIPE if not stripe else CANVAS).darkened(0.05), Vector3(cos(mid), 0.1, sin(mid)))
	# The doorway on +Z (angle PI/2 in x = cos, z = sin).
	var door_a := PI * 0.5
	var half := 0.3
	# Built in slices along the wall's curve so no part of it sinks into
	# the faceted canvas.
	for k in 4:
		var s0 := door_a - half + half * 2.0 * k / 4.0
		var s1 := door_a - half + half * 2.0 * (k + 1) / 4.0
		var n := Vector3(cos((s0 + s1) * 0.5), 0.0, sin((s0 + s1) * 0.5))
		var b0 := _ring_point(s0, WALL_R * 1.02 + 0.03, 0.0)
		var b1 := _ring_point(s1, WALL_R * 1.02 + 0.03, 0.0)
		var t0 := _ring_point(door_a + (s0 - door_a) * 0.8, WALL_R + 0.03, WALL_H + 0.02)
		var t1 := _ring_point(door_a + (s1 - door_a) * 0.8, WALL_R + 0.03, WALL_H + 0.02)
		_tri(st, b0, b1, t1, DOOR, n)
		_tri(st, b0, t1, t0, DOOR, n)
	# Pole and pennant.
	var pole_top := Vector3(0, APEX_H + 0.55, 0)
	_post(st, Vector3(0, APEX_H - 0.05, 0), pole_top, 0.035, POLE)
	var flag := [pole_top, pole_top + Vector3(0, -0.22, 0), pole_top + Vector3(0.42, -0.1, 0.05)]
	_tri(st, flag[0], flag[1], flag[2], STRIPE, Vector3.BACK)
	_tri(st, flag[0], flag[1], flag[2], STRIPE, Vector3.FORWARD)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	# Woven canvas, weathered.
	mat.albedo_texture = load("res://art/third_party/polyhaven/cloth2_diff.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 1.6
	mesh.surface_set_material(0, mat)
	return mesh


static func _ring_point(a: float, r: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)


## One quad of the surface of revolution between two profile rings.
static func _band(st: SurfaceTool, a0: float, a1: float, lo: Array, hi: Array, col: Color) -> void:
	var p00 := _ring_point(a0, lo[0], lo[1])
	var p10 := _ring_point(a1, lo[0], lo[1])
	var p01 := _ring_point(a0, hi[0], hi[1])
	var p11 := _ring_point(a1, hi[0], hi[1])
	# Profile slope gives the normal's lift.
	var dr: float = hi[0] - lo[0]
	var dy: float = hi[1] - lo[1]
	var lift := -dr / maxf(absf(dy), 0.001)
	var n0 := Vector3(cos(a0), lift, sin(a0)).normalized()
	var n1 := Vector3(cos(a1), lift, sin(a1)).normalized()
	var top_col := col.lightened(0.04)
	_emit(st, [[p00, n0, col], [p10, n1, col], [p11, n1, top_col]], n0 + n1)
	_emit(st, [[p00, n0, col], [p11, n1, top_col], [p01, n0, top_col]], n0 + n1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	var nn := n.normalized()
	_emit(st, [[a, nn, col], [b, nn, col], [c, nn, col]], n)


## Emits one triangle wound so its front face (clockwise in Godot) looks
## along `outward`; each vertex is [position, normal, colour].
static func _emit(st: SurfaceTool, verts: Array, outward: Vector3) -> void:
	var a: Vector3 = verts[0][0]
	var b: Vector3 = verts[1][0]
	var c: Vector3 = verts[2][0]
	var order := [0, 1, 2] if (b - a).cross(c - a).dot(outward) < 0.0 else [0, 2, 1]
	for i in order:
		st.set_color(verts[i][2])
		st.set_normal(verts[i][1])
		st.add_vertex(verts[i][0])


static func _post(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		var o0 := Vector3(cos(a0), 0, sin(a0)) * r
		var o1 := Vector3(cos(a1), 0, sin(a1)) * r
		var n0 := o0.normalized()
		var n1 := o1.normalized()
		_emit(st, [[a + o0, n0, col], [a + o1, n1, col], [b + o1, n1, col]], n0 + n1)
		_emit(st, [[a + o0, n0, col], [b + o1, n1, col], [b + o0, n0, col]], n0 + n1)
