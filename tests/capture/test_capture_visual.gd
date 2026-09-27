extends TestCase
## Visual gauntlet: six fixed views (isometric default camera) of the overworld, rendered after every
## visual pass and compared against docs/art_target/. Output name prefix
## comes from VISUAL_TAG (e.g. "v0_before"), default "visual". VISUAL_VIEWS
## (e.g. "56") renders only the listed views, to iterate faster.


func after_each() -> void:
	GameManager.selected_class = null


func _look(p: Player, point: Vector3, pitch: float, distance := -1.0) -> void:
	var d := point - p.global_position
	p.camera_rig.yaw = rad_to_deg(atan2(-d.x, -d.z))
	p.camera_rig.pitch = pitch
	if distance > 0.0:
		p.camera_rig.distance = distance
	p.camera_rig.snap()


func _want(view: int) -> bool:
	var only := OS.get_environment("VISUAL_VIEWS")
	return only == "" or only.contains(str(view))


## Settles for `settle` seconds and captures view `view`, unless filtered out.
func _shot(tag: String, view: int, name: String, settle: float) -> void:
	if not _want(view):
		return
	await wait_seconds(settle)
	await screenshot("%s_%d_%s" % [tag, view, name])


func test_capture_visual_views() -> void:
	var tag := OS.get_environment("VISUAL_TAG")
	if tag == "":
		tag = "visual"
	GameManager.selected_class = load("res://data/classes/fighter.tres")
	var arena := spawn("res://world/regions/test_arena.tscn")
	await wait_seconds(1.0)
	var p: Player = arena.get_node("Player")
	p.controller.input_enabled = false
	for e in arena.get_node("Enemies").get_children():
		e.controller.set_physics_process(false)
	# 1. Overview of the camp from a high, Fabledom-like angle.
	p.global_position = Vector3(2, 0.1, 20)
	_look(p, Vector3(2, 0, 6), -43.0, 17.0)
	await _shot(tag, 1, "overview", 1.2)
	# 2. Normal third-person play near the camp and the woods.
	p.global_position = Vector3(-3, 0.1, 13)
	_look(p, Vector3(-9, 0, 4), -42.0, 17.0)
	await _shot(tag, 2, "gameplay", 1.0)
	# 3. The quarry side, looking across the field to the horizon.
	p.global_position = Vector3(10, 0.1, 14)
	_look(p, Vector3(22, 0, -10), -40.0, 26.0)
	await _shot(tag, 3, "horizon", 1.0)
	# 4. The road north to the crypt.
	p.global_position = Vector3(4, 0.1, -16)
	_look(p, Vector3(4, 0, -30), -42.0, 18.0)
	await _shot(tag, 4, "crypt_road", 1.0)
	# 5. The village-to-be: the same place once a few buildings stand.
	var registry: BuildingRegistry = arena.get_node("NavigationRegion3D/Buildings")
	for spec in [["house", Vector3(-12, 0, 18), 0.4], ["storehouse", Vector3(12, 0, 20), -0.3],
			["blacksmith", Vector3(-13, 0, 26), 0.9], ["farm", Vector3(10, 0, 33), 0.0], ["house", Vector3(-3, 0, 26), 3.3],
			["house", Vector3(-21, 0, 21), 1.3], ["house", Vector3(21, 0, 31), -1.2]]:
		registry.spawn_building(load("res://data/buildings/%s.tres" % spec[0]), Transform3D(Basis(Vector3.UP, spec[2]), spec[1]))
	await wait_seconds(2.0)
	p.global_position = Vector3(1, 0.1, 30)
	_look(p, Vector3(0, 0, 18), -43.0, 23.0)
	await _shot(tag, 5, "village", 1.5)
	# 6. Close on the farm and a house: crops, soil, building detail.
	p.global_position = Vector3(3, 0.1, 38)
	_look(p, Vector3(9, 0, 31), -42.0, 18.0)
	await _shot(tag, 6, "farm", 1.2)
	# 7. The riverside: banks, water and the docks.
	p.global_position = Vector3(24, 0.1, 14)
	_look(p, Vector3(34, 0, 6), -41.0, 18.0)
	await _shot(tag, 7, "river", 1.5)
	# 9. The hamlet quay: the cargo wharf, piers, boats and the far bank.
	p.global_position = Vector3(41, 0.5, 2)
	_look(p, Vector3(40, 0, -4), -42.0, 18.0)
	await _shot(tag, 9, "quay", 1.5)
	# 8. The world map.
	if _want(8):
		var hud := arena.find_child("HUD", true, false)
		if hud == null:
			for n in get_tree().get_nodes_in_group(&"hud"):
				hud = n
		var map: WorldMap = hud.world_map if hud else null
		if map:
			map.toggle()
			await wait_seconds(0.6)
			await screenshot("%s_8_map" % tag)
			map.toggle()
