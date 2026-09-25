extends TestCase
## Phase 0: autoloads exist, save/load round-trips persistent nodes.


class FakePersistent:
	extends Node
	var value := 0
	func get_save_id() -> String: return "test.fake"
	func save_state() -> Dictionary: return {"value": value}
	func load_state(state: Dictionary) -> void: value = int(state["value"])


func test_autoloads_present() -> void:
	for n in ["EventBus", "DataRegistry", "SaveManager", "DebugOverlay", "GameManager"]:
		check(get_tree().root.has_node(n), "autoload %s missing" % n)


func test_save_round_trip() -> void:
	var node := FakePersistent.new()
	node.add_to_group(SaveManager.GROUP)
	add_child(node)
	node.value = 42
	check_eq(SaveManager.save_game("test_slot"), OK, "save succeeds")
	node.value = 0
	check_eq(SaveManager.load_game("test_slot"), OK, "load succeeds")
	check_eq(node.value, 42, "value restored")
	SaveManager.delete_save("test_slot")
	check(not SaveManager.has_save("test_slot"), "save deleted")


func test_game_manager_persists_seed() -> void:
	var seed := GameManager.world_seed
	var state := GameManager.save_state()
	GameManager.world_seed = 1
	GameManager.load_state(state)
	check_eq(GameManager.world_seed, seed, "seed restored")
