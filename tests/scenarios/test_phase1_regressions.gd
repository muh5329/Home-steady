extends TestCase
## Regression tests for issues raised by the Round 1 critic.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const ENEMY := "res://characters/npc/enemy.tscn"
const SKELETON := "res://data/enemies/skeleton_warrior.tres"
const CRATE := "res://items/resources/props/crate.tscn"

var world: Region
var player: Player


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	player.camera_rig.yaw = 0.0
	await wait_seconds(0.3)


func _spawn_enemy(pos: Vector3, ai := true) -> Enemy:
	var enemy: Enemy = load(ENEMY).instantiate()
	enemy.definition = load(SKELETON)
	enemy.position = pos
	world.get_node("Enemies").add_child(enemy)
	if not ai:
		enemy.controller.set_physics_process(false)
	return enemy


func _hit(target: CombatController, amount: float, poise: float) -> void:
	var e := DamageEvent.create(null, amount)
	e.poise_damage = poise
	target.receiver.receive(e)


func test_enemy_chains_its_combo() -> void:
	await _setup_world()
	player.health.max_health = 100000
	player.health.set_current(100000)
	var enemy := _spawn_enemy(Vector3(0, 0.05, -2.0))
	var clips: Array[StringName] = []
	enemy.combat.attack_started.connect(func(a): clips.append(a.animation))
	var chained := await wait_until(func():
		for i in range(1, clips.size()):
			if clips[i] != clips[i - 1]:
				return true
		return false, 15.0)
	check(chained, "skeleton performs its second combo swing (%s)" % [clips])


func test_stagger_cancels_pending_pickup() -> void:
	await _setup_world()
	var crate: Carryable = load(CRATE).instantiate()
	crate.position = Vector3(0, 0.4, -1.2)
	world.get_node("Props").add_child(crate)
	await wait_seconds(0.4)
	await tap(&"interact")
	_hit(player.combat, 5, 999)  # poise break mid-pickup
	await wait_seconds(0.8)
	check(not crate.is_carried(), "pickup cancelled by stagger")
	check(not player.interaction.is_carrying(), "no dangling pending pickup")


func test_dying_drops_carried_item() -> void:
	await _setup_world()
	var crate: Carryable = load(CRATE).instantiate()
	crate.position = Vector3(0, 0.4, -1.2)
	world.get_node("Props").add_child(crate)
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.6)
	check(crate.is_carried(), "carrying before death")
	await hold(&"move_forward", 1.0)
	player.health.take(9999)
	await wait_seconds(0.2)
	check(not crate.is_carried(), "corpse lets go of the crate")
	await wait_seconds(1.5)  # respawn
	check(_dist(crate.global_position, player.global_position) > 1.0, "crate stays behind on respawn")


func test_no_save_while_dead_and_load_revives() -> void:
	await _setup_world()
	check_eq(SaveManager.save_game("test_reg"), OK, "save while alive")
	player.health.take(9999)
	check_eq(SaveManager.save_game("test_reg"), ERR_BUSY, "save refused while dead")
	check_eq(SaveManager.load_game("test_reg"), OK, "load")
	check(player.combat.is_alive(), "loading revives the player")
	check(player.health.current > 0.0, "health restored")
	player.health.take(10)
	check(player.health.current < player.health.max_health, "player can take damage after load")
	SaveManager.delete_save("test_reg")


func test_block_keeps_facing_while_backing_off() -> void:
	await _setup_world()
	var facing0 := player.motor.get_facing()
	press(&"block")
	await wait_seconds(0.2)
	await hold(&"move_back", 0.8)
	var facing1 := player.motor.get_facing()
	release(&"block")
	check(facing0.dot(facing1) > 0.9, "shield stays toward the front while retreating (dot %.2f)" % facing0.dot(facing1))


func test_attackers_take_turns() -> void:
	await _setup_world()
	player.health.max_health = 100000
	player.health.set_current(100000)
	var enemies: Array[Enemy] = []
	for i in 4:
		enemies.append(_spawn_enemy(Vector3(-3 + i * 2, 0.05, -5)))
	var max_simultaneous := 0
	for f in 480:
		var n := 0
		for e in enemies:
			if e.combat.state == CombatController.CombatState.ATTACKING:
				n += 1
		max_simultaneous = maxi(max_simultaneous, n)
		await get_tree().physics_frame
	check(max_simultaneous >= 1, "enemies attack at all")
	check(max_simultaneous <= player.combat.max_attackers, "never more than %d attackers at once (saw %d)" % [player.combat.max_attackers, max_simultaneous])


func test_heavy_cannot_stunlock() -> void:
	await _setup_world()
	var enemy := _spawn_enemy(Vector3(0, 0.05, -1.8), false)
	await wait_seconds(0.3)
	var staggers := [0]
	enemy.combat.staggered.connect(func(): staggers[0] += 1)
	_hit(enemy.combat, 1, 999)
	await wait_seconds(0.95)  # stagger ends, immunity still running
	_hit(enemy.combat, 1, 999)
	check_eq(staggers[0], 1, "second poise break inside immunity window doesn't restagger")


static func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
