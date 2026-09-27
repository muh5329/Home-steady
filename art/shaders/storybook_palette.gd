class_name StorybookPalette
## Applies the storybook re-grade (terracotta roofs, cream plaster, teal
## trim) to every KayKit mesh under a node. One ShaderMaterial per source
## texture, shared.

const SHADER := preload("res://art/shaders/storybook_palette.gdshader")

## Plaster colours (HSV) a building's walls can take: ochre, cream, pale pink.
const WALLS: Array[Vector3] = [Vector3(0.114, 0.46, 0.92), Vector3(0.111, 0.16, 0.95), Vector3(0.045, 0.24, 0.93)]

const ROOF_RED := Vector3(0.054, 0.78, 0.83)
const CLOTH_RED := Vector3(0.01, 0.68, 0.72)

static var _materials: Dictionary = {}  # [Texture2D, weathered, wall, cloth] -> ShaderMaterial


## `weathered` (0..1) turns bright kit stone into old mossy ruin stone;
## `wall` picks the plaster colour from WALLS; `cloth` uses the softer
## character reds (capes, tunics) instead of roof orange.
static func apply(root: Node, weathered := 0.0, wall := 0, cloth := false) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			mi.set_surface_override_material(i, _material_for(src.albedo_texture, weathered, wall, cloth))


static func _material_for(tex: Texture2D, weathered: float, wall: int, cloth: bool) -> ShaderMaterial:
	var key := [tex, weathered, wall, cloth]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter(&"albedo_tex", tex)
		m.set_shader_parameter(&"weathered", weathered)
		m.set_shader_parameter(&"wall_hsv", WALLS[posmod(wall, WALLS.size())])
		m.set_shader_parameter(&"red_hsv", CLOTH_RED if cloth else ROOF_RED)
		m.set_shader_parameter(&"whites_are_plaster", not cloth and weathered == 0.0)
		_materials[key] = m
	return _materials[key]
