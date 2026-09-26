extends TestCase
## Visual capture of the Abandoned Crypt (Phase 8, part 1).


func after_each() -> void:
	GameManager.selected_class = null


func _look(p: Player, point: Vector3, pitch := -16.0) -> void:
	var d := point - p.global_position
	p.camera_rig.yaw = rad_to_deg(atan2(-d.x, -d.z))
	p.camera_rig.pitch = pitch


func _put(p: Player, at: Vector3) -> void:
	p.global_position = at + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	await wait_seconds(0.4)


func test_capture_crypt() -> void:
	GameManager.selected_class = load("res://data/classes/fighter.tres")
	var arena := spawn("res://world/regions/test_arena.tscn")
	await wait_seconds(0.8)
	var p: Player = arena.get_node("Player")
	var vesna: Settler = arena.get_node("Population/Vesna")
	vesna.recruit()
	vesna.join_party()
	for e in arena.get_node("Enemies").get_children():
		e.queue_free()  # the road skeletons would steal the shot
	var entrance: Passage = arena.get_node("NavigationRegion3D/CryptEntrance/Passage")
	var builder: DungeonBuilder = arena.get_node("Crypt/NavigationRegion3D/Builder")
	# 1. The crypt on the hill road.
	await _put(p, entrance.global_position + Vector3(2.5, 0, 9))
	_look(p, entrance.global_position + Vector3(0, 1.5, 0), -8.0)
	vesna.global_position = p.global_position + Vector3(-2, 0, 1)
	await wait_seconds(1.0)
	await screenshot("p8_01_crypt_entrance")
	# 2. Down the stairs: the entrance hall.
	entrance.travel(p)
	await wait_seconds(1.6)
	_look(p, p.global_position + Vector3(0, 0, 6), -34.0)
	await wait_seconds(0.4)
	await screenshot("p8_02_entrance_hall")
	# 3. Room A: skeletons rise.
	var room := builder.cell_global(Vector2i(9, 10))
	await _put(p, room)
	_look(p, builder.cell_global(Vector2i(4, 8)), -34.0)
	await wait_seconds(1.2)
	await screenshot("p8_03_skeletons_rise")
	await wait_seconds(2.5)
	await screenshot("p8_04_crypt_fight")
	# Clear the room for the rest of the tour.
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if is_instance_valid(sp.enemy):
			sp.enemy.health.take(9999)
		sp.is_defeated = true
	# 4. Treasure.
	var chest: Chest = null
	for n in builder.get_children():
		if n is Chest:
			chest = n
	await _put(p, chest.global_position + chest.global_basis.z * 4.0)
	_look(p, chest.global_position, -34.0)
	await wait_seconds(0.8)
	chest.open()
	await wait_seconds(1.2)
	await screenshot("p8_05_treasure")
	# 5. The spike hall.
	var hall := builder.cell_global(Vector2i(6, 13))
	await _put(p, hall)
	_look(p, builder.cell_global(Vector2i(6, 17)), -34.0)
	var trap: SpikeTrap = null
	for n in builder.get_children():
		if n is SpikeTrap:
			trap = n
	await wait_until(func(): return trap.stage() == 2, 4.0)
	await wait_seconds(0.25)
	await screenshot("p8_06_spike_hall")
	# 6. The elite room.
	var elite := builder.cell_global(Vector2i(9, 21))
	await _put(p, elite)
	_look(p, builder.cell_global(Vector2i(9, 24)), -34.0)
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		sp.is_defeated = false
		if sp.definition.id == &"enemy.skeleton_champion":
			var champ: Enemy = sp.spawn()
			champ.controller.set_physics_process(false)
	await wait_seconds(2.5)
	await screenshot("p8_07_champion")
