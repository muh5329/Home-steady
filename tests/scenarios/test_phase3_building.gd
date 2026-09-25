extends TestCase
## Phase 3: placement, construction costs, construction progress.
## Success: resources gathered in the world create a functioning settlement.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const HOUSE := "res://data/buildings/house.tres"
const STOREHOUSE := "res://data/buildings/storehouse.tres"
const STOCKPILE := "res://settlement/storage/stockpile.tscn"

var world: Region
var player: Player
var items: WorldItems
var registry: BuildingRegistry
var build: BuildMode


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	items = world.get_node("Props")
	registry = world.get_node("NavigationRegion3D/Buildings")
	build = world.get_node("BuildMode")
	player.camera_rig.yaw = 0.0
	await wait_seconds(0.3)


func _item(path: String, pos: Vector3) -> Carryable:
	var c: Carryable = load(path).instantiate()
	items.add_child(c)
	c.global_position = pos
	return c


func _fill_materials(site: ConstructionSite) -> void:
	for id in site.needs():
		var data := DataRegistry.get_data(id) as ItemData
		for i in site.remaining(id):
			var c: Carryable = data.carry_scene.instantiate()
			items.add_child(c)
			site.interactable.receive(c)


func _swing_until_done(site: ConstructionSite, max_swings := 30) -> int:
	var swings := 0
	while is_instance_valid(site) and not site.is_queued_for_deletion() and swings < max_swings:
		await tap(&"attack_light")
		await wait_seconds(0.55)
		swings += 1
	return swings


func test_place_house_with_build_mode() -> void:
	await _setup_world()
	await tap(&"build_menu")
	check(build.active, "B opens build mode")
	await tap_key(KEY_2)
	check_eq(build.selected.id, &"building.house", "2 selects House")
	await wait_seconds(0.2)
	check(build.valid, "open ground is valid")
	await tap(&"attack_light")
	await wait_seconds(0.2)
	check_eq(registry.sites().size(), 1, "LMB placed a construction site")
	check(not build.active, "build mode closes after placing")
	check(player.combat.state != CombatController.CombatState.ATTACKING, "placing didn't swing the sword")
	var site := registry.sites()[0]
	check_eq(site.needs().get(&"item.log", 0), 6, "house needs 6 logs")
	check(site.global_position.z < -2.0, "placed in front of the player")


func test_blocked_placement_is_rejected() -> void:
	await _setup_world()
	_item("res://items/resources/props/barrel.tscn", Vector3(0, 0.5, -4.1))
	build.open()
	build.select(load(HOUSE))
	await wait_seconds(0.3)
	check(not build.valid, "a barrel in the footprint blocks placement")
	check(build.confirm() == null, "confirm refuses invalid spot")
	check_eq(registry.sites().size(), 0, "nothing placed")
	build.close()


func test_labour_needs_materials_first() -> void:
	await _setup_world()
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(), Vector3(0, 0, -4.2)))
	await wait_seconds(0.3)
	var work0 := site.work.current
	await tap(&"attack_light")
	await wait_seconds(0.8)
	check_eq(site.work.current, work0, "no progress without materials")


func test_deliver_by_carrying_then_build() -> void:
	await _setup_world()
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(), Vector3(0, 0, -4.2)))
	var log := _item("res://items/resources/props/log.tscn", Vector3(0, 0.4, 1.3))
	player.motor.face(Vector3.BACK, true)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.7)
	check(log.is_carried(), "carrying a log")
	player.motor.face(Vector3.FORWARD, true)
	await wait_seconds(0.4)
	check(player.interaction.focused == site.interactable, "site accepts the carried log")
	await tap(&"interact")
	await wait_seconds(0.3)
	check_eq(site.delivered.get(&"item.log", 0), 1, "E delivered the log")
	var p_mat := site.progress()
	_fill_materials(site)
	check(site.materials_complete(), "all materials in")
	check(site.progress() > p_mat, "progress rises with deliveries")
	var swings := await _swing_until_done(site)
	await wait_seconds(0.3)
	var houses := registry.buildings()
	check_eq(houses.size(), 1, "house finished after %d swings" % swings)
	check_eq(registry.sites().size(), 0, "site replaced by building")
	if houses.size() == 1:
		check_eq(houses[0].definition.id, &"building.house", "it's a house")
		check_eq(get_tree().get_nodes_in_group(HousingComponent.GROUP).size(), 1, "house provides housing")


func test_storehouse_functions_as_storage() -> void:
	await _setup_world()
	var sh := registry.spawn_building(load(STOREHOUSE), Transform3D(Basis(), Vector3(0, 0, -7)))
	await wait_seconds(0.2)
	var storage: Stockpile = sh.get_node("Storage")
	check_eq(storage.inventory.capacity, 120, "large capacity")
	var stone := _item("res://items/resources/props/stone.tscn", Vector3(0, 0.4, 1.3))
	check(storage.interactable.can_accept(stone), "accepts stone")
	storage.interactable.receive(stone)
	check_eq(storage.inventory.count(&"item.stone"), 1, "stored")


func test_stockpile_hands_out_what_sites_need() -> void:
	await _setup_world()
	var pile: Stockpile = load(STOCKPILE).instantiate()
	pile.position = Vector3(0, 0, -3)
	world.add_child(pile)
	pile.inventory.add(&"item.log", 5)
	pile.inventory.add(&"item.stone", 1)
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(), Vector3(9, 0, 0)))
	for i in 6:
		var c: Carryable = load("res://items/resources/props/log.tscn").instantiate()
		items.add_child(c)
		site.interactable.receive(c)
	await wait_seconds(0.5)
	await tap(&"interact")
	await wait_seconds(0.8)
	var carried := player.interaction.carrying
	check(carried != null and carried.item_id == &"item.stone", "took stone (the site's remaining need), not logs")


func test_navigation_routes_around_new_building() -> void:
	await _setup_world()
	registry.spawn_building(load(STOREHOUSE), Transform3D(Basis(), Vector3(0, 0, -8)))
	EventBus.world_geometry_changed.emit()
	var nav: NavigationRegion3D = world.navigation_region
	var baked := [0]
	nav.bake_finished.connect(func(): baked[0] += 1)
	var ok := await wait_until_realtime(func(): return baked[0] > 0, 20.0)
	check(ok, "navmesh rebaked after the building appeared")
	await wait_physics_frames(3)
	var map := nav.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, -2), Vector3(0, 0, -14), true)
	var crosses := false
	for p in path:
		if absf(p.x) < 1.5 and absf(p.z + 8) < 1.5:
			crosses = true
	check(path.size() > 2, "path bends around the building (%d points)" % path.size())
	check(not crosses, "path doesn't go through the building")


func test_save_load_sites_and_buildings() -> void:
	await _setup_world()
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(8, 0, 0)))
	var c: Carryable = load("res://items/resources/props/log.tscn").instantiate()
	items.add_child(c)
	site.interactable.receive(c)
	var sh := registry.spawn_building(load(STOREHOUSE), Transform3D(Basis(), Vector3(-8, 0, 0)))
	(sh.get_node("Storage") as Stockpile).inventory.add(&"item.iron_ore", 7)
	var site_uid := site.uid
	var sh_uid := sh.uid
	await wait_seconds(0.2)
	check_eq(SaveManager.save_game("test_p3"), OK, "saved")
	_fill_materials(site)
	site.work.take(9999)
	await wait_seconds(0.3)
	check_eq(registry.sites().size(), 0, "site completed before load")
	check_eq(SaveManager.load_game("test_p3"), OK, "loaded")
	await wait_seconds(0.3)
	var sites := registry.sites()
	check_eq(sites.size(), 1, "site restored")
	if sites.size() == 1:
		check_eq(sites[0].uid, site_uid, "same uid")
		check_eq(sites[0].delivered.get(&"item.log", 0), 1, "delivered count restored")
		check_near(sites[0].global_rotation.y, PI * 0.5, 0.01, "rotation restored")
	var restored: Array = registry.buildings().filter(func(b): return b.uid == sh_uid)
	check_eq(restored.size(), 1, "storehouse restored with its uid")
	if restored.size() == 1:
		check_eq((restored[0].get_node("Storage") as Stockpile).inventory.count(&"item.iron_ore"), 7, "storehouse contents restored")
	check_eq(registry.buildings().size(), 1, "no leftover house from before the load")
	SaveManager.delete_save("test_p3")


func test_cannot_build_on_fields_or_stumps() -> void:
	await _setup_world()
	registry.spawn_building(load("res://data/buildings/farm.tres"), Transform3D(Basis(), Vector3(0, 0, -4.2)))
	build.open()
	build.select(load(HOUSE))
	await wait_seconds(0.3)
	check(not build.valid, "farm field (no collider) blocks placement")
	build.close()
	await wait_seconds(0.2)
	player.global_position = Vector3(20, 0.05, 0)
	var tree := ResourceNode.new()
	tree.definition = load("res://data/resource_nodes/pine_tree.tres")
	tree.position = Vector3(20, 0, -4.2)
	world.add_child(tree)
	await wait_seconds(0.1)
	tree.health.take(9999)
	await wait_seconds(1.5)
	build.open()
	await wait_seconds(0.3)
	check(not build.valid, "a stump still reserves its ground")
	build.close()


func test_build_mode_owns_the_attack_button() -> void:
	await _setup_world()
	var log := _item("res://items/resources/props/log.tscn", Vector3(0, 0.4, 1.3))
	player.motor.face(Vector3.BACK, true)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.7)
	check(log.is_carried(), "carrying")
	build.open()
	build.select(load("res://data/buildings/stockpile.tres"))
	await wait_seconds(0.3)
	await tap(&"attack_light")
	await wait_seconds(0.6)
	check_eq(registry.sites().size(), 1, "click placed the site")
	check(log.is_carried(), "the same click did not throw the log")


func test_cancel_site_refunds_materials() -> void:
	await _setup_world()
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(), Vector3(0, 0, -4.2)))
	for i in 3:
		site.interactable.receive(_item("res://items/resources/props/log.tscn", Vector3(9, 1, 9)))
	await wait_seconds(0.2)
	build.open()
	await wait_seconds(0.1)
	await tap(&"demolish")
	await wait_seconds(0.5)
	check_eq(registry.sites().size(), 0, "X cancelled the site")
	var logs := items.get_children().filter(func(c): return c is Carryable and c.item_id == &"item.log" and not c.is_queued_for_deletion())
	check_eq(logs.size(), 3, "delivered logs dropped back as physical items")
	build.close()


func test_save_in_completion_frame_still_completes() -> void:
	await _setup_world()
	var site := registry.place_site(load(HOUSE), Transform3D(Basis(), Vector3(0, 0, -4.2)))
	_fill_materials(site)
	site.work.take(9999)
	SaveManager.save_game("test_p3c")  # same frame: site still exists
	await wait_seconds(0.3)
	SaveManager.load_game("test_p3c")
	await wait_seconds(0.5)
	check_eq(registry.sites().size(), 0, "no site stuck at 100%")
	check_eq(registry.buildings().size(), 1, "house exists after load")
	SaveManager.delete_save("test_p3c")
