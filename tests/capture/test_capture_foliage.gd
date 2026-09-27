extends TestCase
## Card foliage (FoliageCards) in a studio: `tools/capture.sh foliage`


func test_capture_foliage() -> void:
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
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor.mesh = plane
	floor.material_override = load("res://art/environments/materials/stylized_ground.tres")
	stage.add_child(floor)
	for i in 3:
		var t := MeshInstance3D.new()
		t.mesh = FoliageCards.tree(i)
		t.scale = Vector3.ONE * (9.0 if i < 2 else 11.0)
		t.position = Vector3(-8 + i * 8, 0, -4)
		stage.add_child(t)
	for i in 3:
		var s := MeshInstance3D.new()
		s.mesh = FoliageCards.shrub(i)
		s.position = Vector3(-5 + i * 3, 0, 3)
		stage.add_child(s)
	var rng := RandomNumberGenerator.new()
	var kinds := [["grass_card.png", Vector2(0.8, 0.7)], ["grass_dry_card.png", Vector2(0.8, 0.9)], ["fern_card.png", Vector2(0.9, 0.8)], ["flower_card.png", Vector2(0.6, 0.6)]]
	for i in 160:
		var k: Array = kinds[i % 4 if i % 5 != 0 else 0]
		var g := MeshInstance3D.new()
		g.mesh = FoliageCards.plant(k[0], k[1])
		g.position = Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(4, 10))
		g.rotation.y = rng.randf() * TAU
		stage.add_child(g)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 6, 22)
	cam.look_at(Vector3(0, 3, 0))
	cam.current = true
	await wait_seconds(0.5)
	await screenshot("foliage_front")
	cam.position = Vector3(12, 26, 26)
	cam.look_at(Vector3(0, 0, 2))
	await wait_seconds(0.3)
	await screenshot("foliage_iso")
