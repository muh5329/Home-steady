class_name BuildMode
extends Node
## Player-facing placement tool. B opens it, number keys pick a building,
## a ghost follows in front of the player, R rotates, attack places,
## X cancels the construction site in front (refunding materials), block
## or B closes. While open it owns the attack/block buttons.

signal opened
signal closed
signal selection_changed(definition: BuildingDefinition)
signal validity_changed(valid: bool, reason: String)
signal placed(site: ConstructionSite)
signal site_cancelled(definition: BuildingDefinition)
## The buildable list changed (something was unlocked, or a save loaded).
signal definitions_changed

const GHOST_OK := Color(0.35, 1.0, 0.45, 0.32)
const GHOST_BAD := Color(1.0, 0.3, 0.25, 0.32)
const GRID := 0.5
## Solid things (world, characters, props) and reserved ground (footprints).
const BLOCKING_MASK := 1 | 2 | 16 | Footprint.LAYER

@export var player: Player
@export var registry: BuildingRegistry

var active := false
var selected: BuildingDefinition
var valid := false

var _definitions: Array[BuildingDefinition] = []
var _ghost: Node3D
var _rotation_steps := 0
var _ghost_ok_mat: StandardMaterial3D
var _ghost_bad_mat: StandardMaterial3D
var _reason := ""
var _query_shape := BoxShape3D.new()


func _ready() -> void:
	_ghost_ok_mat = _make_ghost_material(GHOST_OK)
	_ghost_bad_mat = _make_ghost_material(GHOST_BAD)
	_refresh_definitions()
	EventBus.unlocks_changed.connect(_refresh_definitions)
	if not player.is_node_ready():
		await player.ready
	player.combat.died.connect(close)


func definitions() -> Array[BuildingDefinition]:
	return _definitions


func invalid_reason() -> String:
	return _reason


func is_available(d: BuildingDefinition) -> bool:
	return d.unlocked or Progression.is_unlocked(d.id)


func _refresh_definitions() -> void:
	_definitions.clear()
	for d: BuildingDefinition in DataRegistry.get_all(BuildingDefinition):
		if is_available(d):
			_definitions.append(d)
	_definitions.sort_custom(func(a, b): return a.menu_order < b.menu_order)
	if selected and selected not in _definitions:
		selected = null
		if active and not _definitions.is_empty():
			select(_definitions[0])
	definitions_changed.emit()


func open() -> void:
	if active or not player.combat.is_alive():
		return
	active = true
	player.controller.combat_input_enabled = false
	opened.emit()
	if selected == null and not _definitions.is_empty():
		select(_definitions[0])
	elif selected:
		select(selected)


func close() -> void:
	if not active:
		return
	active = false
	_clear_ghost()
	closed.emit()
	# Hand the buttons back only after the closing click has been consumed
	# by at least one physics tick.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not active:
		player.controller.combat_input_enabled = true


func select(definition: BuildingDefinition) -> void:
	selected = definition
	_clear_ghost()
	_ghost = _make_ghost(definition)
	player.get_parent().add_child(_ghost)
	selection_changed.emit(definition)
	_update_ghost()


## Places the current selection if valid. Returns the site or null.
func confirm() -> ConstructionSite:
	if not active or selected == null:
		return null
	_update_ghost()
	if not valid:
		return null
	var site := registry.place_site(selected, _ghost.global_transform)
	placed.emit(site)
	close()
	return site


## Cancels the construction site at the placement spot (or nearest in
## front), dropping its delivered materials back into the world.
func cancel_site_in_front() -> bool:
	var point := _placement_point(Vector2(2, 2))
	var best: ConstructionSite = null
	var best_d := 4.5
	for site in registry.sites():
		var d := Vector2(site.global_position.x - point.x, site.global_position.z - point.z).length()
		if d < best_d:
			best_d = d
			best = site
	if best == null:
		return false
	var def := best.definition
	registry.cancel_site(best)
	site_cancelled.emit(def)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_menu"):
		if active:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < mini(_definitions.size(), 9):
			select(_definitions[index])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"rotate_building"):
		_rotation_steps = (_rotation_steps + 1) % 4
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"demolish"):
		cancel_site_in_front()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"attack_light"):
		confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"block") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if active and _ghost:
		_update_ghost()


func _placement_point(fp: Vector2) -> Vector3:
	var forward := player.camera_rig.flat_forward()
	var pos := player.global_position + forward * (maxf(fp.x, fp.y) * 0.5 + 1.8)
	return Vector3(snappedf(pos.x, GRID), 0.0, snappedf(pos.z, GRID))


func _update_ghost() -> void:
	var pos := _placement_point(selected.footprint)
	# Rotation comes only from R, so the ghost doesn't flip while orbiting.
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _rotation_steps * PI * 0.5), pos)
	var reason := _check_blocked(_ghost.global_transform, selected)
	var now_valid := reason == ""
	if now_valid != valid or reason != _reason:
		valid = now_valid
		_reason = reason
		_apply_ghost_material(_ghost_ok_mat if valid else _ghost_bad_mat)
		validity_changed.emit(valid, reason)


func _check_blocked(xform: Transform3D, definition: BuildingDefinition) -> String:
	var fp := definition.footprint
	_query_shape.size = Vector3(fp.x, 2.6, fp.y)
	var offset := xform.basis * Vector3(definition.footprint_offset.x, 0, definition.footprint_offset.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_shape
	query.collision_mask = BLOCKING_MASK
	query.collide_with_areas = true
	# Start just above the ground so flat terrain doesn't count.
	query.transform = Transform3D(xform.basis, xform.origin + offset + Vector3.UP * 1.45)
	var hits := player.get_world_3d().direct_space_state.intersect_shape(query, 4)
	for hit in hits:
		return "Too close" if hit["collider"] == player else "Blocked"
	return ""


# --- ghost ------------------------------------------------------------------------

## A ghost is built only from copies of the building's meshes (no scripts,
## lights, particles or colliders), plus a footprint outline.
func _make_ghost(definition: BuildingDefinition) -> Node3D:
	var ghost := Node3D.new()
	ghost.name = "BuildGhost"
	var source: Node3D = definition.scene.instantiate()
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.transform = _relative_transform(source, mesh)
		ghost.add_child(copy)
	source.free()
	var outline := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(definition.footprint.x, 0.08, definition.footprint.y)
	outline.mesh = box
	outline.position = Vector3(definition.footprint_offset.x, 0.04, definition.footprint_offset.y)
	ghost.add_child(outline)
	return ghost


static func _relative_transform(root: Node, node: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p != root and p != null:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _apply_ghost_material(mat: Material) -> void:
	for mesh: GeometryInstance3D in _ghost.find_children("*", "GeometryInstance3D", true, false):
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	valid = false
	_reason = ""


static func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
