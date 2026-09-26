class_name StorybookPalette
## Applies the storybook re-grade (terracotta roofs, cream plaster, teal
## trim) to every KayKit mesh under a node. One ShaderMaterial per source
## texture, shared.

const SHADER := preload("res://art/shaders/storybook_palette.gdshader")

static var _materials: Dictionary = {}  # [Texture2D, weathered] -> ShaderMaterial


## `weathered` (0..1) turns bright kit stone into old mossy ruin stone.
static func apply(root: Node, weathered := 0.0) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			mi.set_surface_override_material(i, _material_for(src.albedo_texture, weathered))


static func _material_for(tex: Texture2D, weathered: float) -> ShaderMaterial:
	var key := [tex, weathered]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter(&"albedo_tex", tex)
		m.set_shader_parameter(&"weathered", weathered)
		_materials[key] = m
	return _materials[key]
