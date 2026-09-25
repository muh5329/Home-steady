extends TestCase
## Phase 2: gather resources, haul physical items, store them.
## Success criterion: cut tree -> obtain log -> carry log -> place in stockpile.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const STOCKPILE := "res://settlement/storage/stockpile.tscn"
const PINE := "res://data/resource_nodes/pine_tree.tres"
const BOULDER := "res://data/resource_nodes/boulder.tres"
const IRON := "res://data/resource_nodes/iron_vein.tres"

var world: Region
var player: Player
var items: WorldItems


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	items = world.get_node("Props")
	player.camera_rig.yaw = 0.0
	await wait_seconds(0.3)


func _spawn_node(def_path: String, pos: Vector3) -> ResourceNode:
	var node := ResourceNode.new()
	node.definition = load(def_path)
	node.position = pos
	node.name = "Node_%d" % randi()
	world.add_child(node)
	return node


func _spawn_stockpile(pos: Vector3) -> Stockpile:
	var s: Stockpile = load(STOCKPILE).instantiate()
	s.position = pos
	world.add_child(s)
	return s


func _loose(item_id: StringName) -> Array[Carryable]:
	var out: Array[Carryable] = []
	for c in items.get_children():
		if c is Carryable and c.item_id == item_id and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _swing_until_depleted(node: ResourceNode, max_swings := 20) -> int:
	var swings := 0
	while not node.is_depleted() and swings < max_swings:
		await tap(&"attack_light")
		await wait_seconds(0.55)
		swings += 1
	return swings


func test_chop_tree_drops_physical_logs() -> void:
	await _setup_world()
	var tree := _spawn_node(PINE, Vector3(0, 0, -1.9))
	await wait_seconds(0.2)
	var swings := await _swing_until_depleted(tree)
	check(tree.is_depleted(), "tree felled after %d swings" % swings)
	check(swings >= 3, "felling takes effort (%d swings)" % swings)
	await wait_seconds(2.0)
	check_eq(_loose(&"item.log").size(), 2, "pine drops 2 physical logs")
	check(not tree.interactable.enabled, "stump is no longer gatherable")


func test_interact_key_swings_at_tree() -> void:
	await _setup_world()
	var tree := _spawn_node(PINE, Vector3(0, 0, -1.9))
	await wait_seconds(0.5)
	check(player.interaction.focused == tree.interactable, "tree is focused (prompt '%s')" % tree.interactable.prompt)
	await tap(&"interact")
	await wait_seconds(0.8)
	check(tree.health.current < tree.health.max_health, "E performs a gathering swing")


func test_monsters_cannot_gather() -> void:
	await _setup_world()
	var tree := _spawn_node(PINE, Vector3(5, 0, 5))
	await wait_seconds(0.1)
	check(not tree.receiver.can_be_hit_by(&"monsters"), "monster hits don't chop trees")
	check(tree.receiver.can_be_hit_by(&"player"), "player can chop")


func test_haul_log_to_stockpile() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -7))
	var tree := _spawn_node(PINE, Vector3(3, 0, -1.9))
	await wait_seconds(0.2)
	player.motor.face(Vector3(3, 0, -1.9) - player.global_position, true)
	await _swing_until_depleted(tree)
	await wait_seconds(2.0)
	var logs := _loose(&"item.log")
	check(logs.size() > 0, "logs on the ground")
	if logs.is_empty():
		return
	# Walk up to a log and pick it up.
	var log := logs[0]
	player.global_position = log.global_position + Vector3(0, 0, 1.2)
	player.global_position.y = 0.05
	player.motor.face(Vector3.FORWARD, true)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.7)
	check(log.is_carried(), "log picked up")
	check(player.interaction.is_carrying_heavy(), "logs are a heavy load")
	# Carry it to the stockpile and put it down.
	player.global_position = Vector3(0, 0.05, -4.6)
	player.motor.face(Vector3.FORWARD, true)
	await wait_seconds(0.3)
	await tap(&"drop")
	await wait_seconds(1.5)
	check_eq(stockpile.inventory.count(&"item.log"), 1, "stockpile counts the delivered log")
	check(not is_instance_valid(log), "physical log absorbed into storage")
	check(stockpile.interactable.prompt.contains("Logs 1"), "prompt shows contents: '%s'" % stockpile.interactable.prompt)


func test_throw_item_onto_stockpile() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -9.5))
	var ore: Carryable = load("res://items/resources/props/iron_ore.tscn").instantiate()
	items.add_child(ore)
	ore.global_position = Vector3(0, 0.4, -1.2)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.6)
	check(ore.is_carried(), "ore picked up")
	player.global_position = Vector3(0, 0.05, -1.5)
	await tap(&"attack_light")  # throw
	var peak := [0.0]
	for i in 150:
		if is_instance_valid(ore):
			peak[0] = ore.global_position.z
		await get_tree().physics_frame
	check_eq(stockpile.inventory.count(&"item.iron_ore"), 1, "thrown ore lands in and is stored (last z=%.2f)" % peak[0])


func test_take_item_back_out() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -3))
	stockpile.inventory.add(&"item.log", 2)
	await wait_seconds(0.5)
	check(player.interaction.focused == stockpile.interactable, "stockpile focused")
	await tap(&"interact")
	await wait_seconds(0.8)
	check(player.interaction.carrying != null and player.interaction.carrying.item_id == &"item.log", "player carries a log taken from the pile")
	check_eq(stockpile.inventory.count(&"item.log"), 1, "count decremented")
	# Walking away must not re-absorb the carried log.
	await hold(&"move_back", 0.6)
	check(player.interaction.carrying != null, "still carrying after leaving the pile")


func test_stockpile_rejects_non_storable() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -5))
	var crate: Carryable = load("res://items/resources/props/crate.tscn").instantiate()
	items.add_child(crate)
	crate.global_position = Vector3(0, 1.0, -5)
	await wait_seconds(1.5)
	check(is_instance_valid(crate), "crates are not absorbed")
	check_eq(stockpile.inventory.total(), 0, "nothing stored")


func test_mining_yields_stone_and_ore() -> void:
	await _setup_world()
	var boulder := _spawn_node(BOULDER, Vector3(0, 0, -2.4))
	await wait_seconds(0.2)
	await _swing_until_depleted(boulder)
	await wait_seconds(1.5)
	check_eq(_loose(&"item.stone").size(), 2, "boulder yields 2 stone")
	player.global_position = Vector3(10, 0.05, 0)
	var vein := _spawn_node(IRON, Vector3(10, 0, -2.3))
	await wait_seconds(0.2)
	player.motor.face(Vector3.FORWARD, true)
	await _swing_until_depleted(vein, 30)
	await wait_seconds(1.5)
	check_eq(_loose(&"item.iron_ore").size(), 3, "iron vein yields 3 ore")


func test_tree_regrows() -> void:
	await _setup_world()
	var tree := _spawn_node(PINE, Vector3(4, 0, 4))
	await wait_seconds(0.1)
	tree.health.take(9999)
	check(tree.is_depleted(), "depleted")
	tree._respawn_left = 0.5
	await wait_seconds(1.0)
	check(not tree.is_depleted(), "regrown after respawn time")
	check_near(tree.health.current, tree.health.max_health, 0.01, "full health again")


func test_save_load_resource_state() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(-6, 0, 0))
	stockpile.name = "TestStockpile"
	var tree := _spawn_node(PINE, Vector3(6, 0, 0))
	tree.name = "TestTree"
	await wait_seconds(0.1)
	tree.health.take(9999)
	await wait_seconds(2.0)
	stockpile.inventory.add(&"item.stone", 3)
	var logs_before := _loose(&"item.log").size()
	check(logs_before == 2, "logs dropped before save")
	check_eq(SaveManager.save_game("test_p2"), OK, "saved")

	# Mess everything up.
	for l in _loose(&"item.log"):
		l.queue_free()
	stockpile.inventory.remove(&"item.stone", 3)
	tree._replenish()
	await wait_seconds(0.2)

	check_eq(SaveManager.load_game("test_p2"), OK, "loaded")
	await wait_seconds(0.2)
	check_eq(_loose(&"item.log").size(), logs_before, "loose logs recreated")
	check_eq(stockpile.inventory.count(&"item.stone"), 3, "stockpile contents restored")
	check(tree.is_depleted(), "tree stays felled")
	SaveManager.delete_save("test_p2")


func test_carried_item_survives_save_load() -> void:
	await _setup_world()
	var ore: Carryable = load("res://items/resources/props/iron_ore.tscn").instantiate()
	items.add_child(ore)
	ore.global_position = Vector3(0, 0.4, -1.2)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.6)
	SaveManager.save_game("test_p2c")
	player.interaction.drop()
	await wait_seconds(0.2)
	SaveManager.load_game("test_p2c")
	await wait_seconds(0.2)
	check(player.interaction.carrying != null and player.interaction.carrying.item_id == &"item.iron_ore", "still carrying the ore after load")
	check_eq(_loose(&"item.iron_ore").size(), 0, "no duplicate ore left on the ground")
	SaveManager.delete_save("test_p2c")


func test_store_carried_item_with_interact() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -4))
	var log: Carryable = load("res://items/resources/props/log.tscn").instantiate()
	items.add_child(log)
	log.global_position = Vector3(0, 0.4, 1.3)
	player.motor.face(Vector3.BACK, true)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.7)
	check(log.is_carried(), "log picked up")
	player.motor.face(Vector3.FORWARD, true)
	player.global_position = Vector3(0, 0.05, -1.2)
	await wait_seconds(0.4)
	check(player.interaction.focused == stockpile.interactable, "stockpile focused while carrying")
	var hud_prompt := ""
	await tap(&"interact")
	await wait_seconds(0.3)
	check_eq(stockpile.inventory.count(&"item.log"), 1, "E stores the carried log directly")
	check(not player.interaction.is_carrying(), "hands are free again")


func test_stockpile_piles_stay_low() -> void:
	await _setup_world()
	var stockpile := _spawn_stockpile(Vector3(0, 0, -6))
	stockpile.inventory.add(&"item.log", 20)
	stockpile.inventory.add(&"item.stone", 15)
	await wait_seconds(0.1)
	var top := 0.0
	for v in stockpile.stack_origin.get_children():
		if v.visible:
			top = maxf(top, v.position.y)
	check(top < 2.6, "stacks capped by layers (top %.2f m)" % top)


func test_save_mid_fall_keeps_logs() -> void:
	await _setup_world()
	var tree := _spawn_node(PINE, Vector3(6, 0, -6))
	tree.name = "FallingTree"
	await wait_seconds(0.1)
	tree.health.take(9999)
	await wait_seconds(0.3)  # mid-fall
	check_eq(SaveManager.save_game("test_fall"), OK, "saved mid-fall")
	await wait_seconds(2.0)
	for l in _loose(&"item.log"):
		l.queue_free()
	await wait_seconds(0.1)
	SaveManager.load_game("test_fall")
	await wait_seconds(0.5)
	check_eq(_loose(&"item.log").size(), 2, "logs saved even though the fall hadn't finished")
	check(tree.is_depleted(), "still felled")
	check(tree.get_node("Pivot").scale.x < 0.1, "no invisible full-size tree left behind")
	SaveManager.delete_save("test_fall")
