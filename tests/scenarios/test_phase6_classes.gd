extends TestCase
## Phase 6: Fighter / Ranger / Wizard as data — melee, ranged, magic.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const ENEMY := "res://characters/npc/enemy.tscn"
const SKELETON := "res://data/enemies/skeleton_warrior.tres"

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
	var e: Enemy = load(ENEMY).instantiate()
	e.definition = load(SKELETON)
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.controller.set_physics_process(false)
	return e


func _damaged(e: Enemy) -> bool:
	return e.health.current < e.health.max_health


func test_each_class_builds_its_body_and_gear() -> void:
	for spec in [["fighter", "Fighter", "weapon.arming_sword", 130.0],
			["ranger", "Ranger", "weapon.hunting_crossbow", 95.0],
			["wizard", "Wizard", "weapon.oak_staff", 85.0]]:
		await _setup(spec[0])
		check_eq(String(player.model_root.name), spec[1], "%s model" % spec[0])
		check_eq(player.equipment.weapon.id, StringName(spec[2]), "%s weapon" % spec[0])
		check_eq(player.health.max_health, spec[3], "%s health" % spec[0])
		check_eq(player.combat.moveset, player.equipment.weapon.moveset, "%s moveset from weapon" % spec[0])
		check_eq(player.abilities.abilities.size(), 1, "%s has an ability" % spec[0])
		cleanup()
		await wait_physics_frames(2)
		GameManager.selected_class = null


func test_fighter_shield_bash_staggers() -> void:
	await _setup("fighter")
	var e := _enemy(Vector3(0, 0.05, -1.8))
	await wait_seconds(0.3)
	var staggered := [false]
	e.combat.staggered.connect(func(): staggered[0] = true)
	await tap(&"ability_1")
	await wait_seconds(1.0)
	check(staggered[0], "shield bash staggers")
	check(not player.abilities.is_ready(0), "on cooldown")


func test_ranger_bolt_hits_distant_enemy() -> void:
	await _setup("ranger")
	var e := _enemy(Vector3(0.5, 0.05, -12))
	await wait_seconds(0.3)
	await tap(&"attack_light")
	var hit := await wait_until(func(): return _damaged(e), 2.0)
	check(hit, "bolt hit an enemy 12 m away")
	check(player.global_position.distance_to(Vector3(0, 0.05, 0)) < 0.5, "shooting didn't lunge")


func test_ranger_volley_hits_several() -> void:
	await _setup("ranger")
	var foes: Array[Enemy] = [_enemy(Vector3(-2.5, 0.05, -9)), _enemy(Vector3(0, 0.05, -9)), _enemy(Vector3(2.5, 0.05, -9))]
	await wait_seconds(0.3)
	player.motor.face(Vector3.FORWARD, true)
	await tap(&"ability_1")
	await wait_seconds(1.5)
	var n := foes.filter(func(f): return _damaged(f)).size()
	check(n >= 2, "volley fan hit %d of 3" % n)


func test_wizard_fireball_hits_a_group() -> void:
	await _setup("wizard")
	var a := _enemy(Vector3(0, 0.05, -10))
	var b := _enemy(Vector3(1.6, 0.05, -10.5))
	var types: Array = []
	for e in [a, b]:
		e.combat.receiver.damage_taken.connect(func(ev): types.append(ev.damage_type))
	await wait_seconds(0.3)
	await tap(&"attack_heavy")
	await wait_until(func(): return _damaged(a) and _damaged(b), 4.0)
	check(_damaged(a) and _damaged(b), "fireball burst hit both")
	check(types.has(DamageEvent.Type.FIRE), "fire damage")


func test_wizard_frost_nova_chills_nearby() -> void:
	await _setup("wizard")
	var near := _enemy(Vector3(2.5, 0.05, 0))
	var far := _enemy(Vector3(0, 0.05, -12))
	await wait_seconds(0.3)
	await tap(&"ability_1")
	await wait_seconds(0.8)
	var fx: StatusEffectComponent = near.get_node("StatusEffects")
	check(fx.has_effect(&"effect.chill"), "nearby enemy chilled")
	check(near.motor.speed_multiplier() < 0.6, "chill slows (x%.2f)" % near.motor.speed_multiplier())
	check(not _damaged(far), "distant enemy untouched")
	await wait_seconds(4.0)
	check(not fx.has_effect(&"effect.chill"), "chill wears off")
	check_near(near.motor.speed_multiplier(), 1.0, 0.01, "speed restored")


func test_ability_cooldown_gates_reuse() -> void:
	await _setup("fighter")
	check(player.abilities.use(0), "first use")
	await wait_seconds(1.2)
	check(not player.abilities.use(0), "second use blocked by cooldown")
	await wait_seconds(7.0)
	check(player.abilities.use(0), "usable after cooldown")


func test_walls_stop_bolts() -> void:
	await _setup("ranger")
	var e := _enemy(Vector3(0, 0.05, -12))
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.5)
	col.shape = box
	wall.add_child(col)
	wall.position = Vector3(0, 2, -6)
	world.add_child(wall)
	await wait_seconds(0.3)
	player.motor.face(Vector3.FORWARD, true)
	await tap(&"attack_light")
	await wait_seconds(1.5)
	check(not _damaged(e), "bolt stopped by the wall")


func test_bolts_pass_friendly_settlers() -> void:
	await _setup("ranger")
	var e := _enemy(Vector3(0, 0.05, -12))
	var pop: Population = world.get_node("Population")
	var s := pop.spawn_settler(Vector3(0, 0.05, -5), "Bystander")
	s.worker.set_physics_process(false)
	await wait_seconds(0.3)
	await tap(&"attack_light")
	await wait_seconds(1.5)
	check(not (s.health.current < s.health.max_health), "settler unharmed")
	check(_damaged(e), "enemy behind was hit")


func test_class_select_screen() -> void:
	GameManager.selected_class = null
	var main: Node = spawn("res://main.tscn")
	await wait_physics_frames(3)
	var menu := main.get_node_or_null("ClassSelect")
	check(menu != null, "class select shown first")
	await tap_key(KEY_3)
	await wait_seconds(0.5)
	check(main.get_node_or_null("ClassSelect") == null or main.get_node("ClassSelect").is_queued_for_deletion(), "menu closed")
	var p := get_tree().get_first_node_in_group(Player.GROUP) as Player
	check(p != null and p.character_class.id == &"class.wizard", "playing a wizard")


func test_class_persists_in_save() -> void:
	await _setup("ranger")
	SaveManager.save_game("test_p6")
	GameManager.selected_class = null
	SaveManager.load_game("test_p6")
	check(GameManager.selected_class != null and GameManager.selected_class.id == &"class.ranger", "class restored")
	SaveManager.delete_save("test_p6")
