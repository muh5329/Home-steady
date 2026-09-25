extends TestCase
## Visual capture of the Phase 1 arena. Run with a renderer:
##   tools/capture.sh phase1


func test_capture_arena() -> void:
	var arena := spawn("res://world/regions/test_arena.tscn")
	var player: Player = arena.get_node("Player")
	await wait_seconds(1.0)
	await screenshot("p1_01_spawn")
	# Pick up a crate and carry it.
	player.camera_rig.yaw = -60.0
	var crate: Carryable = arena.get_node("Props/Crate1")
	player.global_position = crate.global_position + Vector3(-1.2, 0, 0)
	player.global_position.y = 0.05
	player.motor.face(Vector3.RIGHT, true)
	await wait_seconds(0.3)
	await tap(&"interact")
	await wait_seconds(0.6)
	press(&"move_left")
	await wait_seconds(0.6)
	await screenshot("p1_02_carrying")
	release(&"move_left")
	await tap(&"drop")
	# Walk toward the skeletons and fight.
	player.camera_rig.yaw = 0.0
	press(&"move_forward")
	await wait_seconds(1.3)
	release(&"move_forward")
	await wait_seconds(1.0)
	await screenshot("p1_03_engage")
	await tap(&"attack_light")
	await wait_seconds(0.28)
	await screenshot("p1_04_attack")
	await tap(&"attack_light")
	await wait_seconds(0.2)
	await tap(&"attack_light")
	await wait_seconds(0.55)
	await screenshot("p1_05_combo_finisher")
	press(&"block")
	await wait_seconds(1.0)
	await screenshot("p1_06_block")
	release(&"block")
