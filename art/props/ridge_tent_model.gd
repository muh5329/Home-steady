extends MeshInstance3D
## A weathered canvas ridge tent: two poles and a ridge pole, a sagging
## A-frame of linen canvas (photographic cloth texture), a closed back, a
## front flap tied open onto a dark interior, and taut guy ropes to pegs.
## About 3.2 m long, 2.6 m wide and 2.1 m high; the door faces +Z.

const LENGTH := 3.2
const WIDTH := 2.6
const HEIGHT := 2.1

static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = _build()
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _build() -> ArrayMesh:
	var parts := {}
	var canvas := WeaponModel._st(parts, "canvas")
	var hl := LENGTH * 0.5
	var hw := WIDTH * 0.5
	var rows := 8
	var cols := 5
	# Two roof slopes with a gentle sag between the poles.
	for side: float in [-1.0, 1.0]:
		for i in rows:
			for j in cols:
				var z0 := -hl + LENGTH * i / rows
				var z1 := -hl + LENGTH * (i + 1) / rows
				var u0 := float(j) / cols
				var u1 := float(j + 1) / cols
				var p := func(z: float, u: float) -> Vector3:
					var sag := sin(PI * (z + hl) / LENGTH) * 0.08 * sin(PI * u)
					return Vector3(side * hw * u, HEIGHT * (1.0 - u) - sag, z)
				WeaponModel._quad(canvas, p.call(z0, u1), p.call(z0, u0), p.call(z1, u0), p.call(z1, u1))
	# Closed back wall.
	WeaponModel._tri(canvas, Vector3(-hw, 0, -hl), Vector3(0, HEIGHT, -hl), Vector3(hw, 0, -hl))
	# Front: two flaps tied back to the sides, dark inside.
	var inside := WeaponModel._st(parts, "dark")
	WeaponModel._tri(inside, Vector3(-hw * 0.95, 0.01, hl - 0.25), Vector3(0, HEIGHT * 0.98, hl - 0.25), Vector3(hw * 0.95, 0.01, hl - 0.25))
	for side: float in [-1.0, 1.0]:
		WeaponModel._tri(canvas, Vector3(side * hw, 0, hl), Vector3(side * hw * 0.55, HEIGHT * 0.45, hl + 0.05), Vector3(side * hw * 0.38, 0, hl + 0.12))
	# Poles and ridge.
	var wood := WeaponModel._st(parts, "wood")
	for z: float in [-hl - 0.05, hl + 0.05]:
		WeaponModel._cyl(wood, Vector3(0, 0, z), Vector3(0, HEIGHT + 0.25, z), 0.04, 0.035, 6)
	WeaponModel._box(wood, Vector3(0, HEIGHT + 0.02, 0), Vector3(0.06, 0.06, LENGTH + 0.2))
	# Guy ropes to pegs.
	var rope := WeaponModel._st(parts, "rope")
	for z: float in [-hl - 0.05, hl + 0.05]:
		var top := Vector3(0, HEIGHT + 0.2, z)
		var peg := Vector3(0, 0, z + signf(z) * 1.2)
		WeaponModel._box_between(rope, top, peg, 0.015, 0.015)
	for side: float in [-1.0, 1.0]:
		for z: float in [-hl * 0.6, hl * 0.6]:
			WeaponModel._box_between(rope, Vector3(side * hw * 0.55, HEIGHT * 0.45, z), Vector3(side * (hw + 0.8), 0, z), 0.012, 0.012)
	var mesh := ArrayMesh.new()
	for key in parts:
		var st: SurfaceTool = parts[key]
		st.generate_tangents()
		st.commit(mesh)
		var m := StandardMaterial3D.new()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		match key:
			"canvas":
				m.albedo_texture = load("res://art/third_party/polyhaven/cloth2_diff.jpg")
				m.albedo_color = Color(1.25, 1.12, 0.9)
				m.uv1_triplanar = true
				# Coarse and filtered: a fine weave shimmers into moire at range.
				m.uv1_scale = Vector3.ONE * 0.45
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				m.roughness = 0.95
			"dark":
				m.albedo_color = Color(0.08, 0.06, 0.05)
				m.roughness = 1.0
			"wood":
				m.albedo_texture = load("res://art/third_party/ambientcg/Wood060/Wood060_Color.jpg")
				m.albedo_color = Color(0.6, 0.5, 0.42)
				m.uv1_triplanar = true
			"rope":
				m.albedo_color = Color(0.72, 0.64, 0.5)
				m.roughness = 1.0
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh
