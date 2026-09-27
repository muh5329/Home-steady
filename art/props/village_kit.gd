class_name VillageKit
## Quaternius Medieval Village MegaKit (CC0) pieces with our materials.
## The FBX files name their materials (MI_Plaster, MI_WoodTrim, …) but ship
## no textures; `apply` swaps every surface for a shared material by name,
## mixing the kit's own trim sheets with photographic CC0 scans for large
## tiling surfaces (plaster, roof tiles, bricks) so the town reads as
## semi-realistic rather than hand-painted.

const KIT := "res://art/third_party/quaternius/village/"
const TEX := "res://art/third_party/quaternius/village/"

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}


## An instance of a kit piece, e.g. "Wall_Plaster_Straight".
static func piece(piece_name: String) -> Node3D:
	if not _scenes.has(piece_name):
		_scenes[piece_name] = load(KIT + piece_name + ".fbx")
	var node: Node3D = (_scenes[piece_name] as PackedScene).instantiate()
	apply(node)
	return node


static func apply(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src else ""
			var mat := material(key)
			if mat:
				mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func material(mi_name: String) -> Material:
	var key := mi_name.get_slice(".", 0)
	if _materials.has(key):
		return _materials[key]
	var m: Material = null
	match key:
		"MI_Plaster":
			m = _pbr(TEX + "T_Plaster_BaseColor.png", TEX + "T_Plaster_Normal.png", "", Color(1.12, 1.14, 1.3))
			# Weathered: grime rising from the ground, from the photographed plaster.
			(m as StandardMaterial3D).detail_enabled = true
			(m as StandardMaterial3D).detail_albedo = load("res://art/third_party/polyhaven/plaster_diff.jpg")
			(m as StandardMaterial3D).detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			(m as StandardMaterial3D).detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		"MI_WoodTrim":
			m = _pbr(TEX + "T_WoodTrim_BaseColor.png", TEX + "T_WoodTrim_Normal.png", TEX + "T_WoodTrim_Roughness.png", Color(0.42, 0.3, 0.25))
		"MI_WoodTrim_Wear":
			m = _pbr(TEX + "T_WoodTrim_BaseColor.png", TEX + "T_WoodTrim_Normal.png", TEX + "T_WoodTrim_Roughness.png", Color(0.8, 0.74, 0.68))
		"MI_RockTrim":
			m = _pbr(TEX + "T_RockTrim_BaseColor.png", TEX + "T_RockTrim_Normal.png", "", Color(1, 1, 1))
		"MI_Brick":
			m = _pbr(TEX + "T_Brick_BaseColor.png", TEX + "T_Brick_Normal.png", TEX + "T_Brick_Roughness.png", Color(1, 1, 1))
		"MI_RedBrick":
			m = _pbr(TEX + "T_Brick_BaseColor.png", TEX + "T_Brick_Normal.png", TEX + "T_Brick_Roughness.png", Color(1.0, 0.7, 0.62))
		"MI_UnevenBrick":
			m = _pbr(TEX + "T_UnevenBrick_BaseColor.png", TEX + "T_UnevenBrick_Normal.png", TEX + "T_UnevenBrick_Roughness.png", Color(1, 1, 1))
		"MI_RoundTiles":
			# Weathered, moss-flecked terracotta (Poly Haven roof_tiles_14)
			# instead of the kit's bright orange.
			var ph := "res://art/third_party/polyhaven/tex/roof_tiles_14_"
			m = _pbr(ph + "diff.jpg", ph + "nor_gl.jpg", "", Color(1.08, 0.98, 0.9))
			(m as StandardMaterial3D).roughness_texture = null
			(m as StandardMaterial3D).roughness = 0.9
			(m as StandardMaterial3D).metallic_specular = 0.2
		"MI_RoundTiles_Red":
			# Faded red clay tiles for about half the houses.
			var ph := "res://art/third_party/polyhaven/tex/clay_roof_tiles_02_"
			m = _pbr(ph + "diff.jpg", ph + "nor_gl.jpg", "", Color(0.74, 0.5, 0.45))
			(m as StandardMaterial3D).roughness = 0.9
			(m as StandardMaterial3D).metallic_specular = 0.2
		"MI_MetalOrnaments":
			var metal := StandardMaterial3D.new()
			metal.albedo_color = Color(0.16, 0.15, 0.14)
			metal.metallic = 0.7
			metal.roughness = 0.45
			m = metal
		"MI_WindowGlass":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.12, 0.14, 0.16)
			glass.metallic = 0.3
			glass.roughness = 0.08
			m = glass
		"MI_Vine":
			var vine := StandardMaterial3D.new()
			# Leafy detail instead of a flat green: a photographed grass/leaf
			# texture wrapped over the ivy clumps.
			vine.albedo_texture = load("res://art/third_party/ambientcg/Grass001/Grass001_Color.jpg")
			vine.uv1_triplanar = true
			vine.uv1_scale = Vector3.ONE * 2.5
			vine.albedo_color = Color(0.62, 0.78, 0.45)
			vine.roughness = 0.9
			vine.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = vine
	_materials[key] = m
	return m


static func _pbr(albedo: String, normal: String, rough: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(albedo)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(normal)
	if rough != "":
		m.roughness_texture = load(rough)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	else:
		m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
