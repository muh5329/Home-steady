extends TestCase
## Visual capture of the Phase 4 woodcutter at work in the arena.


func test_capture_woodcutter() -> void:
	var arena := spawn("res://world/regions/test_arena.tscn")
	var player: Player = arena.get_node("Player")
	var bjorn: Settler = arena.get_node("Population").settlers()[0]
	player.controller.input_enabled = false
	player.global_position = Vector3(30, 0.05, 30)
	var cam := Camera3D.new()
	arena.add_child(cam)
	var shots := {"Chopping": "p4_01_chopping", "Hauling logs": "p4_02_hauling"}
	var taken := {}
	for f in 60 * 45:
		await get_tree().physics_frame
		var act := bjorn.worker.activity
		if shots.has(act) and not taken.has(act):
			await wait_seconds(0.6 if act == "Chopping" else 1.5)
			# Frame the worker with a close camera.
			cam.global_position = bjorn.global_position + Vector3(3.2, 2.2, 3.6)
			cam.look_at(bjorn.global_position + Vector3.UP * 1.0)
			cam.current = true
			await wait_seconds(0.1)
			await screenshot(shots[act])
			taken[act] = true
		if taken.size() == shots.size():
			break
	var pile: Stockpile = arena.get_node("NavigationRegion3D/Stockpile")
	await wait_until(func(): return pile.inventory.count(&"item.log") >= 1, 40.0)
	cam.global_position = pile.global_position + Vector3(4, 3.5, 5)
	cam.look_at(pile.global_position)
	await wait_seconds(0.5)
	await screenshot("p4_03_delivered")
