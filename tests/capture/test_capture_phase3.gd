extends TestCase
## Visual capture of Phase 3: build mode, construction stages, finished buildings.


func test_capture_building() -> void:
	var arena := spawn("res://world/regions/test_arena.tscn")
	var player: Player = arena.get_node("Player")
	var build: BuildMode = arena.get_node("BuildMode")
	var registry: BuildingRegistry = arena.get_node("NavigationRegion3D/Buildings")
	await wait_seconds(0.8)
	player.camera_rig.yaw = 200.0
	player.camera_rig.pitch = -16.0
	await wait_seconds(0.4)
	await screenshot("p3_01_camp")

	# Build mode ghost (valid).
	player.global_position = Vector3(6, 0.05, 14)
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = -25.0
	await tap(&"build_menu")
	await tap_key(KEY_2)
	await wait_seconds(0.5)
	await screenshot("p3_02_ghost_valid")
	# Blocked: aim at the stockpile.
	player.global_position = Vector3(-4, 0.05, 16.5)
	await wait_seconds(0.5)
	await screenshot("p3_03_ghost_blocked")
	build.close()
	await wait_seconds(0.2)

	# Construction stages side by side.
	var house: BuildingDefinition = load("res://data/buildings/house.tres")
	var positions := [Vector3(8, 0, 20), Vector3(15, 0, 20), Vector3(22, 0, 20)]
	var sites: Array[ConstructionSite] = []
	for p in positions:
		sites.append(registry.place_site(house, Transform3D(Basis(), p)))
	await wait_seconds(0.2)
	for id in house.cost:  # half the materials into the second
		sites[1].delivered[id] = house.cost[id] / 2
		sites[2].delivered[id] = house.cost[id]
	sites[1]._refresh()
	sites[2].work.take(house.build_work * 0.5)
	sites[2]._refresh()
	player.global_position = Vector3(15, 0.05, 30)
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = -18.0
	await wait_seconds(0.6)
	await screenshot("p3_04_construction_stages")

	# A small settlement.
	for s in sites:
		registry.remove_child(s)
		s.queue_free()
	var defs := {
		"house": [Vector3(10, 0, 18), 0.0], "storehouse": [Vector3(18, 0, 17), -PI * 0.5],
		"blacksmith": [Vector3(10, 0, 26), PI * 0.5], "farm": [Vector3(19, 0, 26), 0.0],
	}
	for key in defs:
		var d: BuildingDefinition = load("res://data/buildings/%s.tres" % key)
		registry.spawn_building(d, Transform3D(Basis(Vector3.UP, defs[key][1]), defs[key][0]))
	player.global_position = Vector3(14, 0.05, 32)
	player.camera_rig.yaw = 10.0
	player.camera_rig.pitch = -22.0
	player.camera_rig.distance = 7.5
	await wait_seconds(0.8)
	await screenshot("p3_05_settlement")
