class_name Building
extends StaticBody3D
## A finished building. Its behaviour comes from feature child nodes
## (storage, housing, later workshops) defined in its scene; this root
## only holds identity and persists those features.
##
## Feature nodes join FEATURE_GROUP and implement save_state()/load_state().

const FEATURE_GROUP := &"building_feature"

var definition: BuildingDefinition
## Stable id assigned by the BuildingRegistry (survives save/load).
var uid := ""


func _ready() -> void:
	if definition:
		var fp := definition.footprint
		add_child(Footprint.box(Vector3(fp.x, 2.0, fp.y),
			Vector3(definition.footprint_offset.x, 0, definition.footprint_offset.y)))


func save_state() -> Dictionary:
	var features := {}
	for node in find_children("*", "", true, false):
		if node.is_in_group(FEATURE_GROUP):
			features[String(get_path_to(node))] = node.save_state()
	return {"features": features}


func load_state(state: Dictionary) -> void:
	var features: Dictionary = state.get("features", {})
	for path in features:
		var node := get_node_or_null(NodePath(path))
		if node and node.has_method("load_state"):
			node.load_state(features[path])
