extends TestCase
## Regression tests for issues raised by the Round 4 critic.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const STOCKPILE := "res://settlement/storage/stockpile.tscn"

var world: Region
var player: Player
var population: Population


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	player.controller.input_enabled = false
	population = world.get_node("Population")
	await wait_seconds(0.3)


func _node(def_path: String, pos: Vector3) -> ResourceNode:
	var n := ResourceNode.new()
	n.definition = load(def_path)
	n.position = pos
	world.get_node("NavigationRegion3D").add_child(n)
	return n


func _rebake() -> void:
	world.navigation_region.bake_navigation_mesh(false)
	await wait_physics_frames(2)


func test_downed_worker_releases_claims_and_recovers() -> void:
	await _setup_world()
	var tree := _node("res://data/resource_nodes/pine_tree.tres", Vector3(10, 0, -4))
	await _rebake()
	var w := population.spawn_settler(Vector3(0, 0.05, 4), "Bjorn")
	var claimed := await wait_until(func(): return tree._claimed_by == w.worker, 10.0)
	check(claimed, "worker claimed the tree")
	w.health.take(9999)
	await wait_physics_frames(2)
	check(tree.can_claim(Object.new()), "claim released when downed")
	check_eq(w.worker.activity, "Downed", "shows Downed")
	var back := await wait_until(func(): return w.combat.is_alive(), WorkerController.DOWNED_SECONDS + 2.0)
	check(back, "back on their feet")
	check(w.global_position.distance_to(w.worker.home_position) < 1.0, "recovered at home")


func test_unreachable_target_is_blacklisted() -> void:
	await _setup_world()
	# A tree inside a closed ring of rocks the worker can't path into.
	var tree := _node("res://data/resource_nodes/pine_tree.tres", Vector3(12, 0, -6))
	for i in 10:
		var a := TAU * i / 10.0
		var rock := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 3, 0.6)
		col.shape = box
		col.position.y = 1.5
		rock.add_child(col)
		rock.position = Vector3(12 + cos(a) * 2.6, 0, -6 + sin(a) * 2.6)
		rock.rotation.y = -a + PI * 0.5
		world.get_node("NavigationRegion3D").add_child(rock)
	await _rebake()
	var w := population.spawn_settler(Vector3(0, 0.05, 4), "Bjorn")
	var gave_up := await wait_until(func(): return w.worker.is_blacklisted(tree), 60.0)
	check(gave_up, "worker gives up on an unreachable tree")
	check(tree.can_claim(Object.new()), "and releases it")


func test_distant_workers_work_at_full_pace() -> void:
	await _setup_world()
	var near_tree := _node("res://data/resource_nodes/fir_tree.tres", Vector3(4, 0, -3))
	var far_tree := _node("res://data/resource_nodes/fir_tree.tres", Vector3(4, 0, -103))
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	col.shape = box
	col.position.y = -0.5
	floor.add_child(col)
	floor.position = Vector3(4, 0, -100)
	world.get_node("NavigationRegion3D").add_child(floor)
	await wait_physics_frames(3)  # let the new floor register before anyone stands on it
	await _rebake()
	var near := population.spawn_settler(Vector3(4, 0.3, -1.4), "Near")
	var far := population.spawn_settler(Vector3(4, 0.3, -101.4), "Far")
	near.worker.home_position = near.global_position
	far.worker.home_position = far.global_position
	var t_near := [-1.0]
	var t_far := [-1.0]
	var clock := [0.0]
	var tick := func():
		clock[0] += 1.0 / 60.0
		if t_near[0] < 0 and near_tree.is_depleted(): t_near[0] = clock[0]
		if t_far[0] < 0 and far_tree.is_depleted(): t_far[0] = clock[0]
	get_tree().physics_frame.connect(tick)
	await wait_until(func(): return t_near[0] > 0 and t_far[0] > 0, 60.0)
	if t_far[0] < 0:
		print("DEBUG far state=", far.worker.state_machine.current_name(), " act=", far.worker.activity, " pos=", far.global_position, " claimed=", far_tree._claimed_by)
	get_tree().physics_frame.disconnect(tick)
	check(t_near[0] > 0 and t_far[0] > 0, "both felled their tree")
	check(absf(t_far[0] - t_near[0]) < 2.0, "far worker isn't much slower (near %.1fs, far %.1fs)" % [t_near[0], t_far[0]])


func test_ore_drops_land_clear_of_rubble() -> void:
	await _setup_world()
	var vein := _node("res://data/resource_nodes/iron_vein.tres", Vector3(6, 0, -6))
	await wait_physics_frames(2)
	var e := DamageEvent.create(player, 999.0)
	vein._last_hit_from = Vector3.FORWARD
	vein.health.take(999)
	await wait_seconds(2.5)
	for c in world.get_node("Props").get_children():
		if c is Carryable and c.item_id == &"item.iron_ore":
			var d := Vector2(c.global_position.x - 6, c.global_position.z + 6).length()
			check(d > 1.1 and d < 4.0, "ore rests just outside the rubble (%.2f m)" % d)
