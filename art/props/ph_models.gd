class_name PHModels
## Poly Haven CC0 photoscanned models (art/third_party/polyhaven/models_opt,
## reduced in Blender): trees, rocks, barrels, crates, the pier and ship.
## Each GLB is broken into (mesh, transform) parts once and shared, so the
## same model can be placed as nodes, scattered with MultiMeshes, or flattened
## into one mesh for small props, all keeping the imported LODs where they
## can.

const DIR := "res://art/third_party/polyhaven/models_opt/"

## Tints for leaf materials, per model (photographed leaves read dark and
## olive; the target look is a sunlit, yellow-green summer canopy).
const LEAF_TINT := {
	"island_tree_01": Color(1.25, 1.35, 0.95),
	"island_tree_02": Color(1.2, 1.32, 0.9),
	"island_tree_03": Color(1.2, 1.3, 0.9),
	"tree_small_02": Color(1.15, 1.25, 0.9),
	"bush_01": Color(1.2, 1.32, 0.9),
	"bush_03": Color(1.15, 1.3, 0.88),
}

## Trees used for scenery and choppable trees, with the scale that makes
## each read as a full-grown tree (the scans are 3–5 m saplings).
const TREES := ["island_tree_01", "island_tree_02", "island_tree_03", "tree_small_02"]
const TREE_SCALE := [2.0, 2.3, 2.6, 2.0]

static var _parts: Dictionary = {}
static var _flat: Dictionary = {}


## [[Mesh, Transform3D], ...] relative to the model's root. `only` keeps
## parts whose node name contains any of the given strings.
static func parts(model: String, only: PackedStringArray = PackedStringArray()) -> Array:
	var key := model + "|" + ",".join(only)
	if _parts.has(key):
		return _parts[key]
	var out: Array = []
	var scene: PackedScene = load(DIR + model + ".glb")
	if scene == null:
		push_warning("PHModels: missing " + model)
		_parts[key] = out
		return out
	var root: Node3D = scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not only.is_empty():
			var keep := false
			for s in only:
				if s in String(mi.name):
					keep = true
			if not keep:
				continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		_fix_materials(model, mi.mesh)
		out.append([mi.mesh, xf, String(mi.name)])
	root.free()
	_parts[key] = out
	return out


## A node holding the model's meshes (for single placements).
static func node(model: String, only: PackedStringArray = PackedStringArray(), shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = model.to_pascal_case()
	for p in parts(model, only):
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## Scatters the model at each transform with one MultiMesh per part.
static func emit(parent: Node3D, model: String, xforms: Array, view_end := 0.0, shadows := true, only: PackedStringArray = PackedStringArray()) -> void:
	if xforms.is_empty():
		return
	for p in parts(model, only):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * (p[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view_end > 0.0:
			mmi.visibility_range_end = view_end
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mmi)


## The model flattened into one mesh (small props only: LODs are lost),
## transformed by `xf`.
static func mesh(model: String, only: PackedStringArray = PackedStringArray(), xf := Transform3D.IDENTITY) -> ArrayMesh:
	var key := "%s|%s|%s" % [model, ",".join(only), xf]
	if _flat.has(key):
		return _flat[key]
	var out := ArrayMesh.new()
	for p in parts(model, only):
		var m: Mesh = p[0]
		var t: Transform3D = xf * (p[1] as Transform3D)
		for s in m.get_surface_count():
			var arrays := m.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = t * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in norms.size():
					norms[i] = (t.basis * norms[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = norms
			if arrays[Mesh.ARRAY_TANGENT] != null:
				var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for i in range(0, tans.size(), 4):
					var v := (t.basis * Vector3(tans[i], tans[i + 1], tans[i + 2])).normalized()
					tans[i] = v.x
					tans[i + 1] = v.y
					tans[i + 2] = v.z
				arrays[Mesh.ARRAY_TANGENT] = tans
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, m.surface_get_material(s))
	_flat[key] = out
	return out


## World-space bounds of the model's parts (unscaled).
static func bounds(model: String, only: PackedStringArray = PackedStringArray()) -> AABB:
	var box := AABB()
	var first := true
	for p in parts(model, only):
		var b: AABB = (p[1] as Transform3D) * (p[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Alpha-blended leaves from the glTF become alpha-scissor, double-sided and
## softly lit through, so they sort, shadow and read like foliage.
static func _fix_materials(model: String, m: Mesh) -> void:
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s) as BaseMaterial3D
		if mat == null or mat.has_meta(&"ph_fixed"):
			continue
		mat.set_meta(&"ph_fixed", true)
		var leafy := mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or "lea" in mat.resource_name.to_lower()
		if leafy:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.45
			mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.backlight_enabled = true
			mat.backlight = Color(0.35, 0.4, 0.15)
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			if LEAF_TINT.has(model):
				mat.albedo_color = LEAF_TINT[model]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
