extends StaticBody3D
## Village well: a rough stone drum with a timber frame, a little tiled
## roof, a winch and a bucket (photographic CC0 stone, wood and tile).

static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = _build()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	add_child(mi)


static func _mat(albedo: String, normal: String, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(albedo)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(normal)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _build() -> ArrayMesh:
	var parts := {}
	var stone := WeaponModel._st(parts, "stone")
	var sides := 16
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		for r: float in [0.95, 0.72]:
			var d0 := Vector3(cos(a0), 0, sin(a0)) * r
			var d1 := Vector3(cos(a1), 0, sin(a1)) * r
			WeaponModel._quad(stone, d1, d0, d0 + Vector3.UP * 0.85, d1 + Vector3.UP * 0.85)
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		WeaponModel._quad(stone, o1 * 0.72 + Vector3.UP * 0.85, o0 * 0.72 + Vector3.UP * 0.85, o0 * 1.0 + Vector3.UP * 0.9, o1 * 1.0 + Vector3.UP * 0.9)
	var water := WeaponModel._st(parts, "water")
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		WeaponModel._tri(water, Vector3(0, 0.45, 0), Vector3(cos(a0) * 0.72, 0.45, sin(a0) * 0.72), Vector3(cos(a1) * 0.72, 0.45, sin(a1) * 0.72))
	var wood := WeaponModel._st(parts, "wood")
	for x: float in [-0.85, 0.85]:
		WeaponModel._box(wood, Vector3(x, 1.25, 0), Vector3(0.14, 1.9, 0.14))
	WeaponModel._box(wood, Vector3(0, 2.15, 0), Vector3(1.95, 0.12, 0.12))
	WeaponModel._box(wood, Vector3(0, 1.45, 0), Vector3(1.6, 0.12, 0.12))
	var roof := WeaponModel._st(parts, "roof")
	for sgn: float in [-1.0, 1.0]:
		var ridge := Vector3(0, 2.62, 0)
		var eave := Vector3(0, 1.95, sgn * 0.95)
		WeaponModel._quad(roof, ridge + Vector3(-1.2, 0, 0), ridge + Vector3(1.2, 0, 0), eave + Vector3(1.2, 0, 0), eave + Vector3(-1.2, 0, 0))
	var rope := WeaponModel._st(parts, "rope")
	WeaponModel._box(rope, Vector3(0.1, 1.05, 0), Vector3(0.02, 0.8, 0.02))
	var bucket := PropModel.build(PropModel.Kind.BUCKET)
	var mesh := ArrayMesh.new()
	var mats := {
		"stone": _mat("res://art/third_party/polyhaven/tex/old_stone_wall_diff.jpg", "res://art/third_party/polyhaven/tex/old_stone_wall_nor_gl.jpg", 0.7, Color(1.0, 0.97, 0.92)),
		"wood": _mat("res://art/third_party/ambientcg/Wood060/Wood060_Color.jpg", "res://art/third_party/ambientcg/Wood060/Wood060_NormalGL.jpg", 1.0, Color(0.7, 0.6, 0.52)),
		"roof": _mat("res://art/third_party/polyhaven/tex/roof_tiles_14_diff.jpg", "res://art/third_party/polyhaven/tex/roof_tiles_14_nor_gl.jpg", 0.55, Color(0.95, 0.85, 0.75)),
	}
	for key in parts:
		var st: SurfaceTool = parts[key]
		st.generate_tangents()
		st.commit(mesh)
		var m: Material = mats.get(key)
		if m == null:
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.12, 0.2, 0.2) if key == "water" else Color(0.6, 0.5, 0.35)
			sm.roughness = 0.05 if key == "water" else 0.9
			m = sm
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	# The bucket hangs from the rope.
	for i in bucket.get_surface_count():
		var arrays := bucket.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts.size():
			verts[v] = verts[v] + Vector3(0.1, 0.35, 0)
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, bucket.surface_get_material(i))
	return mesh
