extends TestCase
## Phase 5: generic JobDefinition-driven workers. Farmer and Miner reuse
## the Woodcutter's states with no job-specific code.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const STOCKPILE := "res://settlement/storage/stockpile.tscn"

var world: Region
var player: Player
var population: Population
var registry: BuildingRegistry


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	player.controller.input_enabled = false
	population = world.get_node("Population")
	registry = world.get_node("NavigationRegion3D/Buildings")
	await wait_seconds(0.3)


func _stockpile(pos: Vector3) -> Stockpile:
	var s: Stockpile = load(STOCKPILE).instantiate()
	s.position = pos
	world.get_node("NavigationRegion3D").add_child(s)
	return s


func _node(def_path: String, pos: Vector3) -> ResourceNode:
	var n := ResourceNode.new()
	n.definition = load(def_path)
	n.position = pos
	world.get_node("NavigationRegion3D").add_child(n)
	return n


func _rebake() -> void:
	world.navigation_region.bake_navigation_mesh(false)
	await wait_physics_frames(2)


func _job(id: String) -> JobDefinition:
	return load("res://data/jobs/%s.tres" % id)


func test_worker_states_have_no_job_specific_code() -> void:
	for f in DirAccess.get_files_at("res://ai/jobs/states"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://ai/jobs/states/" + f).to_lower()
		for word in ["woodcut", "miner", "farmer", "&\"item.", "chop", "resourcenode", "stockpile", "constructionsite"]:
			check(not src.contains(word), "no '%s' in %s" % [word, f])


func test_miner_mines_and_hauls_ore() -> void:
	await _setup_world()
	var pile := _stockpile(Vector3(0, 0, 8))
	var vein := _node("res://data/resource_nodes/iron_vein.tres", Vector3(9, 0, -3))
	await _rebake()
	var m := population.spawn_settler(Vector3(2, 0.05, 5), "Dain", "", _job("miner"))
	var ok := await wait_until(func(): return pile.inventory.count(&"item.iron_ore") >= 3, 120.0)
	if not ok:
		for c in world.get_node("Props").get_children():
			print("DEBUG ore ", c.item_id, " at ", c.global_position, " avail=", c.is_available(), " visible=", c.visible, " frozen=", c.freeze)
		print("DEBUG miner state=", m.worker.state_machine.current_name(), " act=", m.worker.activity, " pos=", m.global_position, " carrying=", m.carry.carrying)
	check(vein.is_depleted(), "vein mined out")
	check(ok, "all 3 ore delivered (%d)" % pile.inventory.count(&"item.iron_ore"))
	check_eq(m.worker.job.id, &"job.miner", "is a miner")


func test_miner_ignores_trees_woodcutter_ignores_ore() -> void:
	await _setup_world()
	var tree := _node("res://data/resource_nodes/pine_tree.tres", Vector3(6, 0, -3))
	var vein := _node("res://data/resource_nodes/iron_vein.tres", Vector3(-6, 0, -3))
	check(not tree.has_work_for(_job("miner")), "trees offer no work to miners")
	check(not vein.has_work_for(_job("woodcutter")), "veins offer no work to woodcutters")
	check(vein.has_work_for(_job("miner")), "veins offer work to miners")


func test_farmer_reaps_sows_and_reaps_again() -> void:
	await _setup_world()
	var pile := _stockpile(Vector3(0, 0, 9))
	var farm := registry.spawn_building(load("res://data/buildings/farm.tres"), Transform3D(Basis(), Vector3(8, 0, -4)))
	await wait_physics_frames(2)
	var plots: Array = farm.find_children("Plot*", "", false, false)
	check_eq(plots.size(), 6, "farm has 6 plots")
	for p in plots:
		(p as ResourceNode).definition = p.definition  # plots share the crop definition
	await _rebake()
	population.spawn_settler(Vector3(2, 0.05, 6), "Mira", "", _job("farmer"))
	var reaped := await wait_until(func(): return pile.inventory.count(&"item.wheat") >= 2, 90.0)
	check(reaped, "ripe wheat reaped and hauled (%d)" % pile.inventory.count(&"item.wheat"))
	var sown := await wait_until(func(): return plots.any(func(p): return p._growing), 60.0)
	check(sown, "an empty plot was sown and is growing")


func test_crop_regrows_only_after_sowing() -> void:
	await _setup_world()
	var crop := _node("res://data/resource_nodes/wheat_crop.tres", Vector3(5, 0, 5))
	await wait_physics_frames(2)
	crop.health.take(999)
	check(crop.is_depleted(), "reaped")
	check(crop.needs_tending(), "needs sowing")
	crop._respawn_left = 0.1
	await wait_seconds(1.0)
	check(crop.is_depleted(), "does not regrow by itself")
	crop.apply_work(25.0, player, PackedStringArray(["harvest"]))
	check(not crop.needs_tending(), "sown")
	crop._respawn_left = 0.3
	await wait_seconds(0.6)
	check(crop.is_ripe(), "ripe again after growing")


func test_player_can_sow_with_interact() -> void:
	await _setup_world()
	var crop := _node("res://data/resource_nodes/wheat_crop.tres", Vector3(0, 0, -1.3))
	await wait_physics_frames(2)
	crop.health.take(999)
	await wait_seconds(0.4)
	check(crop.interactable.prompt.begins_with("Sow"), "prompt says Sow ('%s')" % crop.interactable.prompt)
	player.controller.input_enabled = true
	for i in 3:
		await tap(&"interact")
		await wait_seconds(0.9)
	check(crop._growing, "player sowed the plot")


func test_changing_job_by_talking() -> void:
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -1.5), "Bjorn")
	player.controller.input_enabled = true
	await wait_seconds(0.5)
	check(player.interaction.focused == s.interactable, "settler focused")
	var panel: TalkPanel = world.get_node("TalkPanel")
	await tap(&"interact")
	await wait_seconds(0.2)
	check(panel.is_open() and panel.speaker == s, "talking opens the talk panel")
	var texts := panel.option_texts()
	var farmer := -1
	for i in texts.size():
		if texts[i].contains("Farmer"):
			farmer = i
	check(farmer >= 0, "farmer offered (%s)" % [texts])
	await tap_key(KEY_1 + farmer)
	await wait_seconds(0.2)
	check_eq(s.worker.job.id, &"job.farmer", "job changed to farmer")
	check(s.nameplate.text.contains("Farmer"), "nameplate shows new job")
	await tap(&"interact")
	await wait_seconds(0.3)
	check(not panel.is_open(), "E closes the panel")
	check(player.controller.input_enabled, "controls restored")


func test_job_survives_save_load() -> void:
	await _setup_world()
	population.spawn_settler(Vector3(3, 0.05, 3), "Mira", "", _job("farmer"))
	await wait_seconds(0.3)
	SaveManager.save_game("test_p5")
	SaveManager.load_game("test_p5")
	await wait_seconds(0.3)
	var all := population.settlers()
	check_eq(all.size(), 1, "one settler")
	if all.size() == 1:
		check_eq(all[0].worker.job.id, &"job.farmer", "still a farmer")
	SaveManager.delete_save("test_p5")


func test_farm_plots_persist_inside_building() -> void:
	await _setup_world()
	var farm := registry.spawn_building(load("res://data/buildings/farm.tres"), Transform3D(Basis(), Vector3(8, 0, -4)))
	await wait_physics_frames(2)
	var plot: ResourceNode = farm.get_node("Plot0")
	plot.health.take(999)
	plot.apply_work(25.0, player, PackedStringArray())
	var uid := farm.uid
	SaveManager.save_game("test_p5b")
	SaveManager.load_game("test_p5b")
	await wait_seconds(0.3)
	var farms: Array = registry.buildings().filter(func(b): return b.uid == uid)
	check_eq(farms.size(), 1, "farm restored")
	if farms.size() == 1:
		var p: ResourceNode = farms[0].get_node("Plot0")
		check(p.is_depleted() and p._growing, "plot state restored (growing)")
		check(farms[0].get_node("Plot1").is_ripe(), "other plots still ripe")
	SaveManager.delete_save("test_p5b")
