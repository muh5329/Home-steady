extends TestCase
## Phase 1: movement, combat, enemy AI and physical carrying, exercised
## through the real input actions in a sandbox region.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const ENEMY := "res://characters/npc/enemy.tscn"
const SKELETON := "res://data/enemies/skeleton_warrior.tres"
const CRATE := "res://items/resources/props/crate.tscn"
const BARREL := "res://items/resources/props/barrel.tscn"

var world: Region
var player: Player


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	player.camera_rig.yaw = 0.0  # camera looks toward -Z
	await wait_seconds(0.3)


func _spawn_enemy(pos: Vector3, ai := true) -> Enemy:
	var enemy: Enemy = load(ENEMY).instantiate()
	enemy.definition = load(SKELETON)
	enemy.position = pos
	world.get_node("Enemies").add_child(enemy)
	if not ai:
		enemy.controller.set_physics_process(false)
	return enemy


func _spawn_prop(path: String, pos: Vector3) -> Carryable:
	var prop: Carryable = load(path).instantiate()
	prop.position = pos
	world.get_node("Props").add_child(prop)
	return prop


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- movement ---------------------------------------------------------------------

func test_run_walk_sprint_speeds() -> void:
	await _setup_world()
	var start := player.global_position
	await hold(&"move_forward", 1.0)
	var run_d := _flat_distance(start, player.global_position)
	check(player.global_position.z < start.z - 3.0, "forward input moves toward camera forward (-Z)")
	check(run_d > 3.8 and run_d < 5.5, "run ~5 m/s (moved %.2f)" % run_d)
	await wait_seconds(0.5)

	start = player.global_position
	press(&"sprint")
	await hold(&"move_forward", 1.0)
	release(&"sprint")
	var sprint_d := _flat_distance(start, player.global_position)
	check(sprint_d > run_d * 1.3, "sprint faster than run (%.2f vs %.2f)" % [sprint_d, run_d])
	await wait_seconds(0.5)

	start = player.global_position
	press(&"walk")
	await hold(&"move_forward", 1.0)
	release(&"walk")
	var walk_d := _flat_distance(start, player.global_position)
	check(walk_d < run_d * 0.6 and walk_d > 1.0, "walk slower than run (%.2f)" % walk_d)


func test_camera_relative_movement() -> void:
	await _setup_world()
	player.camera_rig.yaw = 90.0  # camera looking toward -X
	var start := player.global_position
	await hold(&"move_forward", 0.6)
	check(player.global_position.x < start.x - 1.5, "forward follows camera yaw")
	await wait_seconds(0.3)
	check(player.motor.get_facing().x < -0.9, "character turns to face movement")


func test_jump_and_land() -> void:
	await _setup_world()
	var ground_y := player.global_position.y
	await tap(&"jump")
	await wait_seconds(0.2)
	check(player.global_position.y > ground_y + 0.5, "jump leaves the ground")
	var landed := await wait_until(func(): return player.is_on_floor(), 2.0)
	check(landed, "lands again")


func test_dodge_moves_fast_with_iframes() -> void:
	await _setup_world()
	var start := player.global_position
	press(&"move_right")
	await wait_physics_frames(2)
	await tap(&"dodge")
	check(player.combat.state == CombatController.CombatState.DODGING, "dodge state entered")
	check(player.combat.receiver.invulnerable, "invulnerable during dodge")
	await wait_seconds(0.5)
	release(&"move_right")
	check(player.global_position.x > start.x + 3.0, "dodge covers ground (%.2f)" % (player.global_position.x - start.x))
	check(not player.combat.receiver.invulnerable, "i-frames end")


# --- combat -----------------------------------------------------------------------

func test_light_combo_chains_and_damages() -> void:
	await _setup_world()
	var enemy := _spawn_enemy(Vector3(0, 0.05, -1.8), false)
	await wait_seconds(0.3)
	var hp0 := enemy.health.current
	var clips: Array[StringName] = []
	player.combat.attack_started.connect(func(a: AttackData): clips.append(a.animation))
	for i in 3:
		await tap(&"attack_light")
		await wait_seconds(0.35)
	await wait_seconds(0.8)
	check_eq(clips.size(), 3, "three attacks started")
	if clips.size() == 3:
		check(clips[0] != clips[1] and clips[1] != clips[2], "combo advances through different swings")
	var dealt := hp0 - enemy.health.current
	check(dealt >= 36.0, "combo damage landed (%.1f)" % dealt)


func test_heavy_attack_staggers() -> void:
	await _setup_world()
	var enemy := _spawn_enemy(Vector3(0, 0.05, -1.8), false)
	await wait_seconds(0.3)
	var staggered := [false]
	enemy.combat.staggered.connect(func(): staggered[0] = true)
	await tap(&"attack_heavy")
	await wait_seconds(1.2)
	check(staggered[0], "heavy attack staggers the enemy")
	check(enemy.health.current <= enemy.health.max_health - 25.0, "heavy deals big damage")


func test_enemy_ai_hunts_and_hits_player() -> void:
	await _setup_world()
	_spawn_enemy(Vector3(0, 0.05, -8), true)
	var hurt := await wait_until(func(): return player.health.current < player.health.max_health, 8.0)
	check(hurt, "skeleton closes distance and damages an idle player")


func test_block_reduces_damage() -> void:
	await _setup_world()
	var enemy := _spawn_enemy(Vector3(0, 0.05, -2.2), true)
	enemy.controller.target = player.combat
	var events: Array[DamageEvent] = []
	player.combat.receiver.damage_taken.connect(func(e): events.append(e))
	press(&"block")
	await wait_until(func(): return events.size() >= 1, 8.0)
	release(&"block")
	check(events.size() >= 1, "enemy attacked the blocking player")
	if events.size() >= 1:
		check(events[0].has_tag("blocked"), "hit was blocked")
		check(events[0].amount <= 3.0, "blocked damage reduced (%.1f)" % events[0].amount)


func test_enemy_dies_and_clears_collision() -> void:
	await _setup_world()
	var enemy := _spawn_enemy(Vector3(0, 0.05, -1.8), false)
	await wait_seconds(0.3)
	var died := [false]
	enemy.combat.died.connect(func(): died[0] = true)
	for i in 12:
		if died[0]:
			break
		await tap(&"attack_light")
		await wait_seconds(0.3)
	await wait_seconds(0.5)
	check(died[0], "enemy killed by repeated attacks")
	check_eq(enemy.collision_layer, 0, "corpse no longer blocks movement")
	check(not enemy.combat.receiver.can_be_hit_by(&"player"), "corpse can't be hit")


func test_player_death_and_respawn() -> void:
	await _setup_world()
	player.global_position = Vector3(5, 0.05, 5)
	player.health.take(9999.0)
	check(not player.combat.is_alive(), "player dies at 0 hp")
	await wait_seconds(1.5)
	check(player.combat.is_alive(), "player respawned")
	check_near(player.health.current, player.health.max_health, 0.01, "full health after respawn")
	check(_flat_distance(player.global_position, Vector3.ZERO) < 0.5, "back at spawn point")


# --- carrying ---------------------------------------------------------------------

func test_pickup_carry_drop() -> void:
	await _setup_world()
	var crate := _spawn_prop(CRATE, Vector3(0, 0.4, -1.2))
	await wait_seconds(0.5)
	check(player.interaction.focused != null, "crate is focused as interactable")
	await tap(&"interact")
	await wait_seconds(0.6)
	check(crate.is_carried(), "crate picked up")
	check(player.interaction.carry_pose.influence > 0.5, "carry pose blends in")
	await hold(&"move_forward", 1.0)
	check(_flat_distance(crate.global_position, player.global_position) < 0.6, "crate travels with player")
	await tap(&"drop")
	await wait_seconds(1.0)
	check(not crate.is_carried(), "crate dropped")
	check(crate.global_position.y < 0.6, "crate rests on the ground (y=%.2f)" % crate.global_position.y)
	check(_flat_distance(crate.global_position, player.global_position) < 2.0, "dropped in front of player")


func test_throw_crate() -> void:
	await _setup_world()
	var crate := _spawn_prop(CRATE, Vector3(0, 0.4, -1.2))
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.6)
	var origin := player.global_position
	await tap(&"attack_light")
	await wait_seconds(1.6)
	check(not crate.is_carried(), "crate released")
	check(_flat_distance(crate.global_position, origin) > 3.5, "crate thrown (%.2f m)" % _flat_distance(crate.global_position, origin))


func test_heavy_load_slows_and_blocks_sprint() -> void:
	await _setup_world()
	var barrel := _spawn_prop(BARREL, Vector3(0, 0.5, -1.2))
	await wait_seconds(0.4)
	await tap(&"interact")
	await wait_seconds(0.6)
	check(barrel.is_carried(), "barrel picked up")
	var start := player.global_position
	press(&"sprint")
	await hold(&"move_forward", 1.0)
	release(&"sprint")
	var d := _flat_distance(start, player.global_position)
	check(d < 3.6, "heavy load: slow and no sprint (%.2f m/s)" % d)


# --- persistence ------------------------------------------------------------------

func test_player_save_load() -> void:
	await _setup_world()
	player.global_position = Vector3(3, 0.05, -4)
	player.health.take(20)
	SaveManager.save_game("test_p1")
	player.global_position = Vector3(-6, 0.05, 6)
	player.health.heal(100)
	SaveManager.load_game("test_p1")
	check(_flat_distance(player.global_position, Vector3(3, 0, -4)) < 0.1, "position restored")
	check_near(player.health.current, player.health.max_health - 20, 0.01, "health restored")
	SaveManager.delete_save("test_p1")
