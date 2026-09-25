extends TestCase
## Visual capture of the Phase 2 resource loop in the arena.


func test_capture_resource_loop() -> void:
	var arena := spawn("res://world/regions/test_arena.tscn")
	var player: Player = arena.get_node("Player")
	var tree: ResourceNode = arena.get_node("NavigationRegion3D/ResourceNodes/Pine2")
	var stockpile: Stockpile = arena.get_node("NavigationRegion3D/Stockpile")
	await wait_seconds(0.5)
	# Stand next to the pine and chop.
	player.global_position = tree.global_position + Vector3(1.9, 0.05, 0.4)
	player.motor.face(tree.global_position - player.global_position, true)
	player.camera_rig.yaw = -60.0
	player.camera_rig.pitch = -14.0
	await wait_seconds(0.4)
	await tap(&"attack_light")
	await wait_seconds(0.4)
	await screenshot("p2_01_chop")
	while not tree.is_depleted():
		await tap(&"attack_light")
		await wait_seconds(0.5)
	await wait_seconds(0.5)
	await screenshot("p2_02_falling")
	await wait_seconds(1.5)
	await screenshot("p2_03_logs")
	# Pick up a log.
	var logs: Array = arena.get_node("Props").get_children().filter(func(c): return c is Carryable and c.item_id == &"item.log")
	var log: Carryable = logs[0]
	player.global_position = log.global_position + Vector3(0, 0, 1.3)
	player.global_position.y = 0.05
	player.motor.face(Vector3.FORWARD, true)
	await wait_seconds(0.3)
	await tap(&"interact")
	await wait_seconds(0.5)
	player.camera_rig.yaw = 150.0
	press(&"move_back")
	await wait_seconds(0.8)
	await screenshot("p2_04_carry_log")
	release(&"move_back")
	# A well-stocked pile.
	stockpile.inventory.add(&"item.log", 6)
	stockpile.inventory.add(&"item.stone", 4)
	stockpile.inventory.add(&"item.iron_ore", 3)
	player.interaction.drop()
	player.global_position = stockpile.global_position + Vector3(3.5, 0.05, 3.5)
	player.camera_rig.yaw = 45.0
	player.camera_rig.pitch = -24.0
	await wait_seconds(0.6)
	await screenshot("p2_05_stockpile")
