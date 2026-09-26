extends TestCase
## Regression tests for issues raised by the Round 5 critic.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"

var world: Region
var player: Player


func after_each() -> void:
	GameManager.selected_class = null


func _setup(class_id: String) -> void:
	GameManager.selected_class = load("res://data/classes/%s.tres" % class_id)
	world = spawn(SANDBOX)
	player = world.player
	player.camera_rig.yaw = 0.0
	await wait_seconds(0.3)


func _enemy(pos: Vector3) -> Enemy:
	var e: Enemy = load("res://characters/npc/enemy.tscn").instantiate()
	e.definition = load("res://data/enemies/skeleton_warrior.tres")
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.controller.set_physics_process(false)
	return e


func test_spells_and_bolts_dont_gather_or_build() -> void:
	await _setup("wizard")
	var crop := ResourceNode.new()
	crop.definition = load("res://data/resource_nodes/wheat_crop.tres")
	crop.position = Vector3(0.6, 0, -8)
	world.get_node("NavigationRegion3D").add_child(crop)
	var registry: BuildingRegistry = world.get_node("NavigationRegion3D/Buildings")
	var site := registry.place_site(load("res://data/buildings/stockpile.tres"), Transform3D(Basis(), Vector3(-2.5, 0, -3)))
	for id in site.needs():
		var data := DataRegistry.get_data(id) as ItemData
		for i in site.remaining(id):
			var c: Carryable = data.carry_scene.instantiate()
			world.get_node("Props").add_child(c)
			site.interactable.receive(c)
	_enemy(Vector3(0, 0.05, -9))
	await wait_seconds(0.3)
	var work0 := site.work.current
	await tap(&"attack_heavy")  # fireball at the enemy next to the crop
	await wait_seconds(2.5)
	await tap(&"ability_1")      # frost nova right next to the site
	await wait_seconds(1.0)
	check(crop.is_ripe(), "fireball didn't reap the wheat")
	check_eq(site.work.current, work0, "spells didn't build the site")


func test_loading_rebuilds_the_saved_class() -> void:
	await _setup("ranger")
	SaveManager.save_game("test_r5")
	cleanup()
	await wait_physics_frames(2)
	await _setup("wizard")
	check_eq(String(player.model_root.name), "Mage", "started as a wizard")
	SaveManager.load_game("test_r5")
	await wait_physics_frames(2)
	check_eq(player.character_class.id, &"class.ranger", "class restored from save")
	check_eq(String(player.model_root.name), "Rogue_Hooded", "ranger body")
	check_eq(player.equipment.weapon.id, &"weapon.hunting_crossbow", "ranger weapon")
	check_eq(player.health.max_health, 95.0, "ranger health")
	check_eq(player.abilities.abilities[0].id, &"ability.volley", "ranger ability")
	check(player.equipment.model_root.find_child("2H_Crossbow", true, false).visible, "crossbow visible")
	SaveManager.delete_save("test_r5")


func test_dropped_ability_press_costs_no_cooldown() -> void:
	await _setup("wizard")
	player.abilities.use(0)
	player.combat.request_light()  # overrides the buffered ability
	await wait_seconds(1.0)
	check(player.abilities.is_ready(0), "ability not spent when it never started")


func test_point_blank_bolt_hits() -> void:
	await _setup("ranger")
	var e := _enemy(Vector3(0, 0.05, -0.9))
	await wait_seconds(0.3)
	player.motor.face(Vector3.FORWARD, true)
	await tap(&"attack_light")
	var hit := await wait_until(func(): return e.health.current < e.health.max_health, 1.5)
	check(hit, "bolt hits an enemy standing on top of you")


func test_frost_nova_is_round() -> void:
	await _setup("wizard")
	var corner := _enemy(Vector3(4.0, 0.05, -4.0))  # 5.7 m: inside a 9x9 box, outside radius 4.5
	var edge := _enemy(Vector3(0, 0.05, -4.0))
	await wait_seconds(0.3)
	await tap(&"ability_1")
	await wait_seconds(1.0)
	check(edge.health.current < edge.health.max_health, "enemy inside the radius hit")
	check_eq(corner.health.current, corner.health.max_health, "enemy in the old box corner untouched")


func test_fireball_pushes_away_from_blast() -> void:
	await _setup("wizard")
	var near := _enemy(Vector3(0, 0.05, -10))
	var behind := _enemy(Vector3(0, 0.05, -12))  # beyond the impact point
	await wait_seconds(0.3)
	var z0 := behind.global_position.z
	await tap(&"attack_heavy")
	await wait_seconds(2.2)
	check(behind.global_position.z < z0 - 0.2, "enemy behind the blast pushed further away (dz %.2f)" % (behind.global_position.z - z0))


func test_ranged_aim_mode() -> void:
	await _setup("ranger")
	press(&"block")
	await wait_seconds(0.6)
	check(player.controller.aiming, "RMB aims with a crossbow")
	check(player.camera_rig.camera.fov < 55.0, "camera zooms")
	check(player.motor.lock_facing, "strafes while aiming")
	release(&"block")
	await wait_seconds(0.6)
	check(not player.controller.aiming, "releases")


func test_fighter_is_tougher() -> void:
	await _setup("fighter")
	var e := DamageEvent.create(null, 20.0)
	player.combat.receiver.receive(e)
	check_near(player.health.max_health - player.health.current, 17.0, 0.01, "takes 15% less damage")
