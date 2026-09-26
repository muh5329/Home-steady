class_name BuildingRegistry
extends Node3D
## Owns every player-placed construction site and building in a region.
## Runtime-spawned entities get a stable `uid`; the registry persists them
## as {uid, definition id, transform, state} and recreates them on load.

const GROUP := &"building_registry"
const SITE_SCENE := preload("res://settlement/construction/construction_site.tscn")

var _next_uid := 1


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)


## Starts construction. Returns the new site.
func place_site(definition: BuildingDefinition, xform: Transform3D, uid := "") -> ConstructionSite:
	var site: ConstructionSite = SITE_SCENE.instantiate()
	site.definition = definition
	site.uid = uid if uid != "" else _new_uid()
	site.name = "Site_" + site.uid
	site.transform = global_transform.affine_inverse() * xform  # placed before _ready runs
	add_child(site)
	site.completed.connect(_on_site_completed)
	EventBus.world_geometry_changed.emit()
	return site


## Creates a finished building directly (loading, scripted events, cheats).
func spawn_building(definition: BuildingDefinition, xform: Transform3D, uid := "") -> Building:
	var building: Building = definition.scene.instantiate()
	building.definition = definition
	building.uid = uid if uid != "" else _new_uid()
	building.name = "Building_" + building.uid
	# Placed before _ready: features (ground wear, storage) see the real spot.
	building.transform = global_transform.affine_inverse() * xform
	add_child(building)
	EventBus.world_geometry_changed.emit()
	return building


func buildings() -> Array[Building]:
	var out: Array[Building] = []
	for c in get_children():
		if c is Building and not c.is_queued_for_deletion():
			out.append(c)
	return out


func sites() -> Array[ConstructionSite]:
	var out: Array[ConstructionSite] = []
	for c in get_children():
		if c is ConstructionSite and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Removes a site and drops what was delivered back into the world.
func cancel_site(site: ConstructionSite) -> void:
	var parent := get_tree().get_first_node_in_group(WorldItems.GROUP)
	var i := 0
	for id in site.delivered:
		var data := DataRegistry.get_data(id) as ItemData
		for n in site.delivered[id]:
			var body: Carryable = data.carry_scene.instantiate()
			(parent if parent else get_parent()).add_child(body)
			var angle := TAU * i / 8.0
			body.global_position = site.global_position + Vector3(cos(angle), 0, sin(angle)) \
				* (maxf(site.definition.footprint.x, site.definition.footprint.y) * 0.5 + 0.8) \
				+ Vector3.UP * (0.5 + 0.5 * (i / 8))
			i += 1
	remove_child(site)
	site.queue_free()
	EventBus.world_geometry_changed.emit()


func _on_site_completed(site: ConstructionSite) -> void:
	var xform := site.global_transform
	var building := spawn_building(site.definition, xform, site.uid)
	remove_child(site)
	site.queue_free()
	EventBus.building_completed.emit(building)


func _new_uid() -> String:
	var uid := "b%d" % _next_uid
	_next_uid += 1
	return uid


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "buildings:%s" % get_path()


func save_state() -> Dictionary:
	var entries := []
	for c in get_children():
		if c.is_queued_for_deletion():
			continue
		var kind := "site" if c is ConstructionSite else "building" if c is Building else ""
		if kind == "":
			continue
		entries.append({
			"uid": c.uid,
			"kind": kind,
			"def": String(c.definition.id),
			"origin": SaveManager.vec3_to_array(c.global_position),
			"yaw": c.global_rotation.y,
			"state": c.save_state(),
		})
	return {"next_uid": _next_uid, "entries": entries}


func load_state(state: Dictionary) -> void:
	for c in get_children():
		if c is ConstructionSite or c is Building:
			remove_child(c)
			c.queue_free()
	_next_uid = int(state.get("next_uid", 1))
	for e in state.get("entries", []):
		var def := DataRegistry.get_data(StringName(e["def"])) as BuildingDefinition
		if def == null:
			continue
		var xform := Transform3D(Basis(Vector3.UP, float(e["yaw"])), SaveManager.array_to_vec3(e["origin"]))
		var node: Node
		if e["kind"] == "site":
			node = place_site(def, xform, e["uid"])
		else:
			node = spawn_building(def, xform, e["uid"])
		node.load_state(e.get("state", {}))
	EventBus.world_geometry_changed.emit()
