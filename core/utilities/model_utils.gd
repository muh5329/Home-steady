class_name ModelUtils
## Helpers for imported character/prop models.


## Hides mesh parts by node name (KayKit rigs ship every weapon/shield
## variant attached; equipment decides which are visible).
static func set_parts_visible(model: Node, part_names: PackedStringArray, is_visible: bool) -> void:
	for part_name in part_names:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			part.visible = is_visible
		else:
			push_warning("ModelUtils: no part '%s' in %s" % [part_name, model.name])


## Enables shadows on every mesh under `root`.
static func enable_shadows(root: Node) -> void:
	for mesh: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Attaches an instance of `item` to a skeleton bone (e.g. "handslot.r").
static func attach_to_bone(model: Node, bone_name: String, item: PackedScene) -> Node3D:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone(bone_name) < 0:
		push_warning("ModelUtils: no bone '%s' in %s" % [bone_name, model.name])
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Attach_" + bone_name.replace(".", "_")
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var instance: Node3D = item.instantiate()
	attachment.add_child(instance)
	return instance
