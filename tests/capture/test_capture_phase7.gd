extends TestCase
## Visual capture of Phase 7: meeting Vesna, the party following,
## companions fighting, a downed companion, and going back to work.


func after_each() -> void:
	GameManager.selected_class = null


func _arena() -> Node:
	GameManager.selected_class = load("res://data/classes/fighter.tres")
	var arena := spawn("res://world/regions/test_arena.tscn")
	await wait_seconds(0.8)
	return arena


func _enemy(arena: Node, pos: Vector3) -> Enemy:
	var e: Enemy = load("res://characters/npc/enemy.tscn").instantiate()
	e.definition = load("res://data/enemies/skeleton_warrior.tres")
	e.position = pos
	arena.get_node("Enemies").add_child(e)
	return e


## Points the camera from the player toward `point`.
func _look(p: Player, point: Vector3, pitch := -14.0) -> void:
	var d := point - p.global_position
	p.camera_rig.yaw = rad_to_deg(atan2(-d.x, -d.z))
	p.camera_rig.pitch = pitch


func test_capture_companions() -> void:
	var arena := await _arena()
	var p: Player = arena.get_node("Player")
	var vesna: Settler = arena.get_node("Population/Vesna")
	var bjorn: Settler = arena.get_node("Population/Bjorn")
	# 1. Meeting the stranger.
	p.global_position = vesna.global_position + Vector3(1.4, 0, 1.4)
	p.motor.face(vesna.global_position - p.global_position, true)
	p.camera_rig.yaw = 45.0
	p.camera_rig.pitch = -10.0
	await wait_seconds(0.6)
	await screenshot("p7_01_stranger_prompt")
	await tap(&"interact")
	await wait_seconds(0.4)
	await screenshot("p7_02_talk_stranger")
	await tap_key(KEY_1)  # invite (the camp has a free bed)
	await wait_seconds(0.4)
	await screenshot("p7_03_talk_recruited")
	await tap_key(KEY_1)  # join my party
	await wait_seconds(0.3)
	check(bjorn.join_party(), "Bjorn joins too")
	# 2. Following across the open field south of camp.
	p.global_position = Vector3(3, 0.1, 17)
	await wait_seconds(1.5)
	p.controller.input_enabled = true
	p.camera_rig.yaw = 180.0
	p.camera_rig.pitch = -16.0
	await hold(&"move_forward", 4.0)
	p.controller.input_enabled = false
	await wait_seconds(1.0)
	_look(p, p.global_position + Vector3(0.6, 0, -1))  # look back at the party
	await wait_seconds(0.3)
	await screenshot("p7_04_party_following")
	# 3. A fight: two skeletons come at us from the south.
	_enemy(arena, p.global_position + Vector3(-3, 0, 10))
	_enemy(arena, p.global_position + Vector3(3, 0, 11))
	_look(p, p.global_position + Vector3(0, 0, 8), -18.0)
	await wait_seconds(2.2)
	await screenshot("p7_05_party_fight")
	await wait_seconds(1.5)
	await screenshot("p7_06_party_fight_later")
	# 4. Bjorn goes down; the HUD and prompt say so.
	for e in arena.get_node("Enemies").get_children():
		e.queue_free()
	await wait_seconds(0.5)
	bjorn.health.take(9999)
	p.global_position = bjorn.global_position + Vector3(1.2, 0, 1.2)
	p.motor.face(bjorn.global_position - p.global_position, true)
	_look(p, bjorn.global_position)
	await wait_seconds(1.6)
	await screenshot("p7_07_downed_companion")
	# 5. Home again: Vesna returns to the settlement and works.
	await tap(&"interact")  # revive
	await wait_seconds(1.5)
	vesna.set_job(load("res://data/jobs/woodcutter.tres"))
	vesna.send_home()
	var working := await wait_until(func(): return vesna.worker.activity.begins_with("Chopping"), 60.0)
	check(working, "Vesna went home and chops wood")
	p.global_position = vesna.global_position + Vector3(3.0, 0, 3.0)
	_look(p, vesna.global_position + Vector3(-1.5, 0, 0), -12.0)
	await wait_seconds(0.5)
	await screenshot("p7_08_vesna_back_at_work")
