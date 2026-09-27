extends TestCase
## Kit houses (settlement/buildings/kit_house.gd) in a studio: `tools/capture.sh kit`


func test_capture_kit_houses() -> void:
	var stage := Node3D.new()
	add_child(stage)
	_spawned.append(stage)
	var env := WorldEnvironment.new()
	env.environment = load("res://art/environments/default_environment.tres")
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.7
	sun.light_color = Color(1, 0.88, 0.7)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var specs := [[3, 3, 2, 1, Vector3(-9, 0, 0)], [3, 4, 2, 0, Vector3(0, 0, 0)], [4, 5, 1, 2, Vector3(10, 0, 0)], [2, 3, 1, 1, Vector3(-9, 0, 11)]]
	for s in specs:
		var h := KitHouse.new()
		h.width_cells = s[0]
		h.depth_cells = s[1]
		h.floors = s[2]
		h.style = s[3]
		h.random_seed = int(s[4].x) + 7
		h.position = s[4]
		stage.add_child(h)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 7, 24)
	cam.look_at(Vector3(0, 3, 0))
	cam.current = true
	await wait_seconds(0.5)
	await screenshot("kit_front")
	cam.position = Vector3(18, 26, 26)
	cam.look_at(Vector3(0, 0, 3))
	await wait_seconds(0.3)
	await screenshot("kit_iso")
	cam.position = Vector3(-6, 6, -22)
	cam.look_at(Vector3(0, 3, 0))
	await wait_seconds(0.3)
	await screenshot("kit_back")
