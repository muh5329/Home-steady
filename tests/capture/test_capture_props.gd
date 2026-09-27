extends TestCase
## Realistic props and the pier/boat set in a studio: `tools/capture.sh props`


func test_capture_props() -> void:
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
	plane.size = Vector2(40, 40)
	floor.mesh = plane
	floor.material_override = load("res://art/environments/materials/stylized_ground.tres")
	stage.add_child(floor)
	var kinds := [PropModel.Kind.BARREL, PropModel.Kind.BARREL_LYING, PropModel.Kind.SACK, PropModel.Kind.BENCH, PropModel.Kind.LOG_PILE, PropModel.Kind.POST]
	for i in kinds.size():
		var p := PropModel.new()
		p.kind = kinds[i]
		p.position = Vector3(-5 + i * 1.8, 0, 2)
		stage.add_child(p)
	var boat := PropModel.new()
	boat.kind = PropModel.Kind.ROWBOAT
	boat.position = Vector3(-3, 0, -3)
	boat.rotation_degrees.y = 70
	stage.add_child(boat)
	var pier := PropModel.new()
	pier.kind = PropModel.Kind.PIER
	pier.length = 8.0
	pier.position = Vector3(4, 0.4, -3)
	stage.add_child(pier)
	for n in ["wooden_crate_01", "jug_01", "round_wooden_table_01", "wooden_display_shelves_01", "stone_01"]:
		var path := "res://art/third_party/polyhaven/models/%s/%s_1k.fbx" % [n, n]
		var m: Node3D = load(path).instantiate()
		m.position = Vector3(-5 + ["wooden_crate_01", "jug_01", "round_wooden_table_01", "wooden_display_shelves_01", "stone_01"].find(n) * 2.2, 0, 5.5)
		stage.add_child(m)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 5, 13)
	cam.look_at(Vector3(0, 0.5, 1))
	cam.current = true
	await wait_seconds(0.5)
	await screenshot("props_front")
	cam.position = Vector3(8, 16, 16)
	cam.look_at(Vector3(0, 0, 1))
	await wait_seconds(0.3)
	await screenshot("props_iso")
