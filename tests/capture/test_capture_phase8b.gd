extends TestCase
## Visual capture of Phase 8 part 2: spiders, the locked door, the
## Necromancer fight, and the reward back home.


func after_each() -> void:
	GameManager.selected_class = null


func _look(p: Player, point: Vector3, pitch := -34.0) -> void:
	var d := point - p.global_position
	p.camera_rig.yaw = rad_to_deg(atan2(-d.x, -d.z))
	p.camera_rig.pitch = pitch


func _put(p: Player, at: Vector3) -> void:
	p.global_position = at + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	p.camera_rig.snap()
	await wait_seconds(0.4)


func test_capture_boss() -> void:
	GameManager.selected_class = load("res://data/classes/wizard.tres")
	var arena := spawn("res://world/regions/test_arena.tscn")
	await wait_seconds(0.8)
	var p: Player = arena.get_node("Player")
	p.controller.input_enabled = false
	p.health.max_health = 4000.0
	p.health.set_current(4000.0)
	var vesna: Settler = arena.get_node("Population/Vesna")
	vesna.recruit()
	vesna.join_party()
	for e in arena.get_node("Enemies").get_children():
		e.queue_free()
	var builder: DungeonBuilder = arena.get_node("Crypt/NavigationRegion3D/Builder")
	var spawns := {}
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		sp.is_defeated = true
		spawns[sp.definition.id] = sp
	# 1. Spiders drop from the dark.
	var lair := builder.cell_global(Vector2i(9, 27))
	await _put(p, builder.cell_global(Vector2i(10, 29)))
	vesna.companion.teleport_to_leader()
	var gate: CryptGate = null
	for n in builder.get_children():
		if n is CryptGate:
			gate = n
	gate.open(false)
	_look(p, lair, -40.0)
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if sp.definition.id == &"enemy.crypt_spider":
			sp.is_defeated = false
			sp.spawn()
	await wait_seconds(0.45)
	await screenshot("p8b_01_spiders_drop")
	await wait_seconds(2.0)
	await screenshot("p8b_02_spider_fight")
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if is_instance_valid(sp.enemy):
			sp.enemy.health.take(9999)
		sp.is_defeated = true
	# 2. The locked door (shown closed, with the key in hand).
	gate.is_open = false
	gate._update()
	await _put(p, gate.global_position + gate.global_basis.z * 1.6)
	p.motor.face(gate.global_position - p.global_position, true)
	_look(p, gate.global_position, -30.0)
	var key: Carryable = (load("res://data/items/resources/crypt_key.tres") as ItemData).carry_scene.instantiate()
	arena.get_node("Props").add_child(key)
	key.global_position = p.global_position + Vector3.UP
	p.carry.hold_immediately(key)
	await wait_seconds(0.8)
	await screenshot("p8b_03_locked_door")
	p.carry.deposit(gate.interactable)
	await wait_seconds(1.5)
	await screenshot("p8b_04_door_opens")
	# 3. Morvath.
	var boss_spawn: EnemySpawn = spawns[&"enemy.necromancer"]
	boss_spawn.is_defeated = false
	var boss := boss_spawn.spawn()
	await wait_seconds(1.5)
	await _put(p, boss.global_position + Vector3(-5, 0, 5))
	vesna.companion.teleport_to_leader()
	_look(p, boss.global_position, -32.0)
	await wait_until(func(): return boss.abilities.summons_alive() > 0, 10.0)
	await wait_seconds(0.8)
	await screenshot("p8b_05_raise_dead")
	await wait_seconds(2.5)
	_look(p, boss.global_position, -32.0)
	await screenshot("p8b_06_boss_fight")
	boss.health.set_current(boss.health.max_health * 0.4)
	await _put(p, boss.global_position + Vector3(-1.8, 0, 1.8))
	_look(p, boss.global_position, -40.0)
	var nova := [false]
	boss.abilities.ability_used.connect(func(_i, a): nova[0] = nova[0] or a.id == &"ability.grave_nova")
	await wait_until(func(): return nova[0], 8.0)
	await wait_seconds(0.55)
	await screenshot("p8b_07_grave_nova")
	# 4. Victory: the rune drops, the Blacksmith unlocks.
	boss.health.take(99999)
	await wait_seconds(1.2)
	await _put(p, boss.global_position + Vector3(0, 0, 4))
	_look(p, boss.global_position, -30.0)
	await wait_seconds(0.3)
	await screenshot("p8b_08_victory_rune")
	# 5. Home: the Blacksmith site takes the rune.
	await _put(p, Vector3(10, 0.1, 22))
	var registry: BuildingRegistry = arena.get_node("NavigationRegion3D/Buildings")
	var site := registry.place_site(load("res://data/buildings/blacksmith.tres"), Transform3D(Basis(), Vector3(10, 0, 16)))
	await wait_seconds(0.5)
	var rune: Carryable = null
	for c in arena.get_node("Props").get_children():
		if c is Carryable and c.item_id == &"item.forge_rune":
			rune = c
	rune.global_position = p.global_position + Vector3.UP
	p.carry.hold_immediately(rune)
	_look(p, site.global_position, -20.0)
	p.motor.face(site.global_position - p.global_position, true)
	await wait_seconds(0.8)
	await screenshot("p8b_09_rune_home")
