extends TestCase
## The HUD over the sandbox (quick UI check): `tools/capture.sh capture_hud`


func test_capture_hud() -> void:
	GameManager.selected_class = load("res://data/classes/fighter.tres")
	var world := spawn("res://tests/fixtures/sandbox.tscn")
	var hud: HUD = load("res://ui/hud/hud.gd").new()
	hud.player = world.get_node("Player")
	world.add_child(hud)
	await wait_seconds(1.0)
	hud.player.health.take(40)
	await wait_seconds(0.5)
	await screenshot("hud_sandbox")
	GameManager.selected_class = null
