extends TestCase
## Phase 8 (part 2): spiders, the champion's key and the locked door, the
## Necromancer boss (abilities, summons, phases), and the reward that
## feeds the settlement: the Forge Rune + the Blacksmith unlock.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const CRYPT := "res://dungeons/crypt/crypt.tscn"

var world: Region
var player: Player
var crypt: Node3D
var builder: DungeonBuilder


func _setup() -> void:
	world = spawn(SANDBOX)
	player = world.player
	player.controller.input_enabled = false
	crypt = load(CRYPT).instantiate()
	crypt.position = Vector3(400, 0, 0)
	world.add_child(crypt)
	builder = crypt.get_node("NavigationRegion3D/Builder")
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		sp.is_defeated = true  # tests raise what they need
	await wait_seconds(0.3)


func _spawn_of(id: StringName) -> EnemySpawn:
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if sp.definition.id == id:
			return sp
	return null


func _raise(id: StringName) -> Enemy:
	var sp := _spawn_of(id)
	sp.is_defeated = false
	return sp.spawn()


func _place_player(at: Vector3) -> void:
	player.global_position = at + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.camera_rig.snap()
	await wait_physics_frames(3)


func _gate() -> CryptGate:
	for n in builder.get_children():
		if n is CryptGate:
			return n
	return null


func _loose(id: StringName) -> Array[Carryable]:
	var out: Array[Carryable] = []
	for c in world.get_node("Props").get_children():
		if c is Carryable and c.item_id == id and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _path_length_ok(from: Vector3, to: Vector3) -> bool:
	var map := world.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(to) < 1.5


# --- spider ------------------------------------------------------------------------------------

func test_spider_is_a_working_monster_that_poisons() -> void:
	await _setup()
	var spider := _raise(&"enemy.crypt_spider")
	check(spider.find_child("AnimationPlayer", true, false) != null, "procedural spider body has an animation player")
	for clip in [&"Idle", &"Walking_A", &"Running_A", &"Spider_Bite", &"Spider_Leap", &"Death_A", &"Hit_A", &"Spawn_Drop"]:
		check(spider.get_node("CharacterAnimator").has_animation(clip), "clip %s" % clip)
	await wait_seconds(1.2)  # the drop from the ceiling
	await _place_player(spider.global_position + Vector3(0, 0, 3))
	var poisoned := await wait_until(func(): return player.get_node("StatusEffects").has_effect(&"effect.poison"), 8.0)
	check(poisoned, "the bite poisons")
	# Step out of reach: only the poison can hurt now.
	spider.controller.set_physics_process(false)
	await _place_player(spider.global_position + Vector3(0, 0, 12))
	var hp := player.health.current
	await wait_seconds(1.0)
	check(player.health.current < hp - 1.5, "poison ticks damage (%.1f -> %.1f)" % [hp, player.health.current])
	spider.health.take(9999)
	await wait_seconds(1.2)
	check(not spider.combat.is_alive(), "dies like any monster")


# --- key and door ---------------------------------------------------------------------------

func test_champion_key_opens_the_boss_door() -> void:
	await _setup()
	var gate := _gate()
	check(gate != null and not gate.is_open, "a locked door before the boss")
	var elite := builder.cell_global(Vector2i(9, 24))
	var beyond := builder.cell_global(Vector2i(10, 29))
	check(not _path_length_ok(elite, beyond), "no way past the locked door")
	var champ := _raise(&"enemy.skeleton_champion")
	await wait_physics_frames(2)
	champ.health.take(9999)
	await wait_seconds(0.8)
	var keys := _loose(&"item.crypt_key")
	check_eq(keys.size(), 1, "the champion dropped the key")
	# Carry it to the door and hand it over (E), like delivering to storage.
	await _place_player(gate.global_position + gate.global_basis.z * 1.8)
	player.carry.hold_immediately(keys[0])
	player.motor.face(gate.global_position - player.global_position, true)
	player.controller.input_enabled = true
	await wait_seconds(0.4)
	check(player.interaction.focused == gate.interactable, "door focused with the key in hand")
	await tap(&"interact")
	await wait_seconds(0.3)
	check(gate.is_open, "the key opened the door")
	check(not player.carry.is_carrying(), "key used up")
	var reachable := await wait_until_realtime(func(): return _path_length_ok(elite, beyond), 3.0)
	check(reachable, "navigation now leads past the door")
	SaveManager.save_game("test_p8b_gate")
	SaveManager.load_game("test_p8b_gate")
	await wait_physics_frames(2)
	check(gate.is_open, "stays open after loading")
	SaveManager.delete_save("test_p8b_gate")


# --- the boss --------------------------------------------------------------------------------

func test_necromancer_casts_summons_and_novas() -> void:
	await _setup()
	var engaged := [false]
	EventBus.boss_engaged.connect(func(_b): engaged[0] = true)
	var boss := _raise(&"enemy.necromancer")
	var used := {}
	boss.abilities.ability_used.connect(func(_i, a): used[a.id] = true)
	await wait_seconds(1.5)
	player.health.max_health = 5000.0
	player.health.set_current(5000.0)
	await _place_player(boss.global_position + Vector3(0, 0, 9))
	var summoned := await wait_until(func(): return boss.abilities.summons_alive() > 0, 10.0)
	check(summoned, "Raise Dead brought minions up")
	check(engaged[0], "the fight was announced (boss bar)")
	# Healthy: crowding him is safe from the nova.
	await _place_player(boss.global_position + Vector3(0, 0, 2.2))
	await wait_seconds(4.0)
	check(not used.has(&"ability.grave_nova"), "no nova above 60% health, even point-blank")
	boss.health.set_current(boss.health.max_health * 0.55)
	await _place_player(boss.global_position + Vector3(0, 0, 2.2))
	var nova := await wait_until(func(): return used.has(&"ability.grave_nova"), 8.0)
	check(nova, "below 60%: crowding him gets you blasted")
	check(not used.has(&"ability.raise_the_fallen"), "but no warriors yet above 50%")
	boss.health.set_current(boss.health.max_health * 0.45)
	var fallen := await wait_until(func(): return used.has(&"ability.raise_the_fallen"), 20.0)
	check(fallen, "below 50%: he raises crypt warriors")


func test_defeating_the_boss_feeds_the_settlement() -> void:
	await _setup()
	var build_mode: BuildMode = world.get_node("BuildMode")
	var blacksmith := load("res://data/buildings/blacksmith.tres") as BuildingDefinition
	check(blacksmith not in build_mode.definitions(), "the Blacksmith starts locked")
	check(blacksmith.cost.has(&"item.forge_rune"), "and needs the Forge Rune")
	var boss := _raise(&"enemy.necromancer")
	await wait_seconds(1.5)
	await _place_player(boss.global_position + Vector3(0, 0, 9))
	var summoned := await wait_until(func(): return boss.abilities.summons_alive() > 0, 10.0)
	var defeated := [false]
	EventBus.boss_defeated.connect(func(_b): defeated[0] = true)
	boss.health.take(9999)
	await wait_seconds(0.8)
	check(defeated[0], "boss_defeated announced")
	check_eq(boss.abilities.summons_alive(), 0, "his minions crumble with him")
	check_eq(_loose(&"item.forge_rune").size(), 1, "the Forge Rune dropped")
	check(Progression.is_unlocked(&"building.blacksmith"), "Blacksmith unlocked")
	check(blacksmith in build_mode.definitions(), "and offered in the build menu")
	# The unlock is part of the save.
	SaveManager.save_game("test_p8b_unlock")
	Progression.reset()
	check(blacksmith not in build_mode.definitions(), "reset hides it again")
	SaveManager.load_game("test_p8b_unlock")
	check(blacksmith in build_mode.definitions(), "loading restores the unlock")
	SaveManager.delete_save("test_p8b_unlock")


func test_forge_rune_builds_the_blacksmith() -> void:
	await _setup()
	Progression.unlock(&"building.blacksmith")
	var registry: BuildingRegistry = world.get_node("NavigationRegion3D/Buildings")
	var site := registry.place_site(load("res://data/buildings/blacksmith.tres"), Transform3D(Basis(), Vector3(6, 0, -6)))
	await wait_physics_frames(2)
	check_eq(site.needs().get(&"item.forge_rune", 0), 1, "the site asks for the rune")
	var rune: Carryable = (load("res://data/items/resources/forge_rune.tres") as ItemData).carry_scene.instantiate()
	world.get_node("Props").add_child(rune)
	rune.global_position = Vector3(0, 0.5, -2)
	await wait_physics_frames(2)
	check(site.accepts(rune), "the site accepts the rune")
	check(site.deliver(rune), "delivered")
	check_eq(site.needs().get(&"item.forge_rune", 0), 0, "rune requirement met")


# --- critic regressions (round 8) -------------------------------------------------------

func test_hits_do_not_cancel_a_summon() -> void:
	await _setup()
	var boss := _raise(&"enemy.necromancer")
	await wait_seconds(1.5)
	player.health.max_health = 5000.0
	player.health.set_current(5000.0)
	await _place_player(boss.global_position + Vector3(0, 0, 9))
	var anim: CharacterAnimator = boss.get_node("CharacterAnimator")
	var casting := await wait_until(func(): return boss.combat.state == CombatController.CombatState.BUSY \
		and anim.current_action() == &"Spellcast_Summon", 10.0)
	check(casting, "started casting Raise Dead")
	for i in 3:  # a companion's arrows pepper him mid-cast
		var ev := DamageEvent.create(player, 3.0, DamageEvent.Type.PHYSICAL)
		ev.source_combatant = player.combat
		ev.poise_damage = 4.0
		boss.combat.receiver.receive(ev)
		await wait_seconds(0.25)
	var up := await wait_until(func(): return boss.abilities.summons_alive() > 0, 2.0)
	check(up, "the armored cast still raised minions")


func test_loading_mid_fight_leaves_no_orphaned_minions() -> void:
	await _setup()
	var sp := _spawn_of(&"enemy.necromancer")
	sp.is_defeated = false
	SaveManager.save_game("test_p8b_midfight")
	var boss := sp.spawn()
	await wait_seconds(1.5)
	await _place_player(boss.global_position + Vector3(0, 0, 9))
	player.health.max_health = 5000.0
	player.health.set_current(5000.0)
	await wait_until(func(): return boss.abilities.summons_alive() > 0, 10.0)
	SaveManager.load_game("test_p8b_midfight")
	await wait_physics_frames(3)
	var living := 0
	for e in builder.get_children():
		if e is Enemy and not e.is_queued_for_deletion() and e.combat.is_alive():
			living += 1
	check(living <= 1, "only a freshly risen boss may remain (%d living)" % living)
	SaveManager.delete_save("test_p8b_midfight")


func test_boss_resets_when_the_party_leaves() -> void:
	await _setup()
	var disengaged := [false]
	EventBus.boss_disengaged.connect(func(_b): disengaged[0] = true)
	var boss := _raise(&"enemy.necromancer")
	await wait_seconds(1.5)
	player.health.max_health = 5000.0
	player.health.set_current(5000.0)
	await _place_player(boss.global_position + Vector3(0, 0, 9))
	await wait_until(func(): return boss.controller.target != null, 4.0)
	await wait_seconds(0.6)
	boss.health.set_current(boss.health.max_health * 0.3)
	await _place_player(builder.cell_global(Vector2i(7, 2)))  # back at the entrance
	var reset := await wait_until(func(): return boss.health.current >= boss.health.max_health, 25.0)
	check(reset, "healed back to full after giving up the chase")
	check(disengaged[0], "boss bar hidden")
	check_eq(boss.abilities.summons_alive(), 0, "minions dismissed")


func test_a_lost_key_turns_up_again() -> void:
	await _setup()
	var champ_spawn := _spawn_of(&"enemy.skeleton_champion")
	champ_spawn.is_defeated = true  # e.g. an older save: champion dead, no key anywhere
	var gate := _gate()
	var found := await wait_until(func(): return _loose(&"item.crypt_key").size() == 1, 4.0)
	check(found, "a replacement key appears by the door")
	if found:
		check(_loose(&"item.crypt_key")[0].global_position.distance_to(gate.global_position) < 4.0, "right by the door")
	await wait_seconds(2.5)
	check_eq(_loose(&"item.crypt_key").size(), 1, "and only one")


func test_closing_the_door_on_load_blocks_the_way_again() -> void:
	await _setup()
	var gate := _gate()
	SaveManager.save_game("test_p8b_closed")
	gate.open()
	var elite := builder.cell_global(Vector2i(9, 24))
	var beyond := builder.cell_global(Vector2i(10, 29))
	check(await wait_until_realtime(func(): return _path_length_ok(elite, beyond), 3.0), "open: passable")
	SaveManager.load_game("test_p8b_closed")
	check(not gate.is_open, "closed again after loading")
	var blocked := await wait_until_realtime(func(): return not _path_length_ok(elite, beyond), 3.0)
	check(blocked, "navigation rebaked around the closed door")
	SaveManager.delete_save("test_p8b_closed")


func test_items_never_fall_out_of_the_world() -> void:
	await _setup()
	var rune: Carryable = (load("res://data/items/resources/forge_rune.tres") as ItemData).carry_scene.instantiate()
	world.get_node("Props").add_child(rune)
	rune.global_position = Vector3(0, -40, 0)
	var back := await wait_until(func(): return rune.global_position.y > -5.0, 3.0)
	check(back, "the rune came back to the player")
	check(rune.global_position.distance_to(player.global_position) < 4.0, "near the player")
