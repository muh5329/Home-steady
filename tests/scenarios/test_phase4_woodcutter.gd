extends TestCase
## Phase 4: one autonomous Woodcutter.
## Loop: find tree -> walk to tree -> chop -> collect log -> deliver -> repeat.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const STOCKPILE := "res://settlement/storage/stockpile.tscn"
const PINE := "res://data/resource_nodes/pine_tree.tres"

var world: Region
var player: Player
var population: Population
var items: WorldItems


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	population = world.get_node("Population")
	items = world.get_node("Props")
	player.controller.input_enabled = false
	await wait_seconds(0.3)


func _stockpile(pos: Vector3) -> Stockpile:
	var s: Stockpile = load(STOCKPILE).instantiate()
	s.position = pos
	world.get_node("NavigationRegion3D").add_child(s)
	return s


func _tree(pos: Vector3) -> ResourceNode:
	var n := ResourceNode.new()
	n.definition = load(PINE)
	n.position = pos
	world.get_node("NavigationRegion3D").add_child(n)
	return n


func _rebake() -> void:
	var nav: NavigationRegion3D = world.navigation_region
	nav.bake_navigation_mesh(false)
	await wait_physics_frames(2)


func test_woodcutter_full_loop() -> void:
	await _setup_world()
	var pile := _stockpile(Vector3(0, 0, 8))
	var tree := _tree(Vector3(9, 0, -4))
	await _rebake()
	var w := population.spawn_settler(Vector3(3, 0.05, 6), "Bjorn")
	var seen := {}
	w.worker.activity_changed.connect(func(a): seen[a] = true)
	var first := await wait_until(func(): return pile.inventory.count(&"item.log") >= 1, 60.0)
	check(first, "first log delivered autonomously")
	check(tree.is_depleted(), "the woodcutter felled the tree")
	var both := await wait_until(func(): return pile.inventory.count(&"item.log") >= 2, 60.0)
	check(both, "went back for the second log (count %d)" % pile.inventory.count(&"item.log"))
	check(seen.has("Chopping"), "was seen chopping (%s)" % [seen.keys()])
	check(seen.keys().any(func(k): return String(k).begins_with("Hauling")), "was seen hauling")
	check_eq(player.global_position.distance_to(Vector3(0, 0.05, 0)) < 1.0, true, "player never moved (no input)")


func test_woodcutter_repeats_on_next_tree() -> void:
	await _setup_world()
	var pile := _stockpile(Vector3(0, 0, 8))
	var t1 := _tree(Vector3(8, 0, 0))
	var t2 := _tree(Vector3(-8, 0, 2))
	await _rebake()
	population.spawn_settler(Vector3(0, 0.05, 4), "Bjorn")
	var ok := await wait_until(func(): return t1.is_depleted() and t2.is_depleted(), 150.0)
	check(ok, "moved on to the next tree after hauling")
	var all := await wait_until(func(): return pile.inventory.count(&"item.log") >= 4, 120.0)
	check(all, "all 4 logs hauled (%d)" % pile.inventory.count(&"item.log"))


func test_two_woodcutters_reserve_different_trees() -> void:
	await _setup_world()
	_stockpile(Vector3(0, 0, 8))
	var t1 := _tree(Vector3(8, 0, -2))
	var t2 := _tree(Vector3(-8, 0, -2))
	await _rebake()
	var a := population.spawn_settler(Vector3(1, 0.05, 5), "A")
	var b := population.spawn_settler(Vector3(-1, 0.05, 5), "B")
	var split := await wait_until(func():
		return t1._claimed_by != null and t2._claimed_by != null and t1._claimed_by != t2._claimed_by, 10.0)
	check(split, "each worker claimed a different tree")


func test_hauls_logs_the_player_left_behind() -> void:
	await _setup_world()
	var pile := _stockpile(Vector3(0, 0, 8))
	for i in 2:
		var log: Carryable = load("res://items/resources/props/log.tscn").instantiate()
		items.add_child(log)
		log.global_position = Vector3(6 + i * 1.6, 0.4, -3)
	await _rebake()
	population.spawn_settler(Vector3(2, 0.05, 5), "Bjorn")
	var ok := await wait_until(func(): return pile.inventory.count(&"item.log") >= 2, 60.0)
	check(ok, "loose logs collected and stored")


func test_worker_waits_without_storage() -> void:
	await _setup_world()
	var tree := _tree(Vector3(6, 0, -2))
	await _rebake()
	var w := population.spawn_settler(Vector3(2, 0.05, 3), "Bjorn")
	var carrying := await wait_until(func(): return w.carry.carrying != null, 40.0)
	check(carrying, "picked up a log after felling")
	await wait_seconds(3.0)
	check(w.worker.activity.contains("nowhere to store"), "reports missing storage: '%s'" % w.worker.activity)
	check(w.carry.carrying != null, "keeps the log instead of dropping it")


func test_worker_flees_when_attacked() -> void:
	await _setup_world()
	_tree(Vector3(12, 0, -2))
	await _rebake()
	var w := population.spawn_settler(Vector3(3, 0.05, 3), "Bjorn")
	await wait_seconds(1.0)
	var skeleton: Enemy = load("res://characters/npc/enemy.tscn").instantiate()
	skeleton.definition = load("res://data/enemies/skeleton_warrior.tres")
	var e := DamageEvent.create(skeleton, 5.0)
	world.get_node("Enemies").add_child(skeleton)
	skeleton.global_position = w.global_position + Vector3(2, 0, 0)
	skeleton.controller.set_physics_process(false)
	await wait_physics_frames(2)
	e.source_combatant = skeleton.combat
	w.combat.receiver.receive(e)
	await wait_seconds(0.3)
	check_eq(w.worker.state_machine.current_name(), &"Flee", "flees after being hit")


func test_settlers_persist_mid_haul() -> void:
	await _setup_world()
	var w := population.spawn_settler(Vector3(4, 0.05, 4), "Bjorn")
	await wait_seconds(0.3)
	var log: Carryable = load("res://items/resources/props/log.tscn").instantiate()
	w.add_child(log)
	w.carry.hold_immediately(log)
	var uid := w.uid
	check_eq(SaveManager.save_game("test_p4"), OK, "saved")
	w.carry.discard_carried()
	w.global_position = Vector3(-10, 0.05, -10)
	check_eq(SaveManager.load_game("test_p4"), OK, "loaded")
	await wait_seconds(0.3)
	var all := population.settlers()
	check_eq(all.size(), 1, "one settler after load")
	if all.size() == 1:
		var s: Settler = all[0]
		check_eq(s.uid, uid, "same uid")
		check_eq(s.settler_name, "Bjorn", "same name")
		check(s.carry.carrying != null and s.carry.carrying.item_id == &"item.log", "still carrying the log")
	SaveManager.delete_save("test_p4")
