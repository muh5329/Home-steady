extends TestCase
## Visual capture of Phase 6: class select + each class fighting.


func after_each() -> void:
	GameManager.selected_class = null


func test_capture_class_select() -> void:
	GameManager.selected_class = null
	spawn("res://main.tscn")
	await wait_seconds(0.5)
	await screenshot("p6_01_class_select")


func _arena(class_id: String) -> Node:
	GameManager.selected_class = load("res://data/classes/%s.tres" % class_id)
	var arena := spawn("res://world/regions/test_arena.tscn")
	await wait_seconds(0.6)
	return arena


func _enemy(arena: Node, pos: Vector3) -> Enemy:
	var e: Enemy = load("res://characters/npc/enemy.tscn").instantiate()
	e.definition = load("res://data/enemies/skeleton_warrior.tres")
	e.position = pos
	arena.get_node("Enemies").add_child(e)
	e.controller.set_physics_process(false)
	return e


func test_capture_ranger() -> void:
	var arena := await _arena("ranger")
	var p: Player = arena.get_node("Player")
	p.global_position = Vector3(10, 0.05, 20)
	p.camera_rig.yaw = -20.0
	p.camera_rig.pitch = -12.0
	_enemy(arena, Vector3(13, 0.05, 6))
	await wait_seconds(0.5)
	await tap(&"attack_light")
	await wait_seconds(0.12)
	await screenshot("p6_02_ranger_shot")
	await wait_seconds(0.8)
	await tap(&"ability_1")
	await wait_seconds(0.2)
	await screenshot("p6_03_ranger_volley")


func test_capture_wizard() -> void:
	var arena := await _arena("wizard")
	var p: Player = arena.get_node("Player")
	p.global_position = Vector3(10, 0.05, 20)
	p.camera_rig.yaw = -10.0
	p.camera_rig.pitch = -14.0
	_enemy(arena, Vector3(12, 0.05, 11))
	_enemy(arena, Vector3(13.5, 0.05, 11.5))
	await wait_seconds(0.5)
	await tap(&"attack_heavy")
	await wait_seconds(1.25)
	await screenshot("p6_04_wizard_fireball")
	await wait_seconds(0.9)
	await screenshot("p6_05_wizard_fireball_burst")
	p.global_position = Vector3(12.5, 0.05, 13.5)
	await wait_seconds(0.4)
	await tap(&"ability_1")
	await wait_seconds(0.55)
	await screenshot("p6_06_wizard_frost_nova")


func test_capture_fighter() -> void:
	var arena := await _arena("fighter")
	var p: Player = arena.get_node("Player")
	p.global_position = Vector3(10, 0.05, 14)
	p.camera_rig.yaw = 60.0
	p.camera_rig.pitch = -10.0
	_enemy(arena, Vector3(10, 0.05, 12.2))
	p.motor.face(Vector3.FORWARD, true)
	await wait_seconds(0.5)
	await tap(&"ability_1")
	await wait_seconds(0.42)
	await screenshot("p6_07_fighter_bash")
