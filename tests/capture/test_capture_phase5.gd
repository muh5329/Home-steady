extends TestCase
## Visual capture of Phase 5: farmer and miner running the generic job loop.


func test_capture_jobs() -> void:
	var arena := spawn("res://world/regions/test_arena.tscn")
	var player: Player = arena.get_node("Player")
	var registry: BuildingRegistry = arena.get_node("NavigationRegion3D/Buildings")
	player.controller.input_enabled = false
	player.global_position = Vector3(30, 0.05, 30)
	var farm := registry.spawn_building(load("res://data/buildings/farm.tres"), Transform3D(Basis(), Vector3(9, 0, 17)))
	await wait_seconds(2.0)  # navmesh rebake
	var mira: Settler = arena.get_node("Population/Mira")
	var dain: Settler = arena.get_node("Population/Dain")
	var cam := Camera3D.new()
	arena.add_child(cam)
	cam.current = true
	var shots := [[mira, "Farming", "p5_01_farmer_reaping"], [dain, "Mining", "p5_02_miner_mining"]]
	for shot in shots:
		var s: Settler = shot[0]
		var ok := await wait_until(func(): return s.worker.activity == shot[1], 60.0)
		await wait_seconds(0.5)
		cam.global_position = s.global_position + Vector3(3.0, 2.4, 3.4)
		cam.look_at(s.global_position + Vector3.UP * 0.9)
		await wait_seconds(0.1)
		await screenshot(shot[2])
	# Wait for the farmer to sow a plot after hauling.
	await wait_until(func(): return farm.find_children("Plot*", "", false, false).any(func(p): return p._growing), 90.0)
	await wait_seconds(8.0)
	cam.global_position = farm.global_position + Vector3(0, 6, 7)
	cam.look_at(farm.global_position)
	await wait_seconds(0.1)
	await screenshot("p5_03_farm_growing")
