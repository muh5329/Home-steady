extends TestCase
## Poly Haven model lineup in a studio: `tools/capture.sh test_capture_ph`

const DIR := "res://art/third_party/polyhaven/models_opt/"


func test_capture_ph() -> void:
	var stage := Node3D.new()
	add_child(stage)
	_spawned.append(stage)
	var env := WorldEnvironment.new()
	env.environment = load("res://art/environments/default_environment.tres")
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.7
	sun.light_color = Color(1, 0.9, 0.75)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor.mesh = plane
	floor.material_override = load("res://art/environments/materials/stylized_ground.tres")
	stage.add_child(floor)
	var small := ["wine_barrel_01", "wooden_barrels_01", "wooden_crate_02", "painted_wooden_bench", "planter_box_01", "stone_fire_pit", "wooden_lantern_01", "fern_02", "shrub_02", "shrub_03", "nettle_plant", "tree_stump_01", "rock_moss_set_01", "rock_moss_set_02", "dead_tree_trunk"]
	for i in small.size():
		var m: Node3D = load(DIR + small[i] + ".glb").instantiate()
		m.position = Vector3(-10 + (i % 8) * 2.8, 0, 4 + (i / 8) * 3.5)
		stage.add_child(m)
	var big := ["island_tree_01", "island_tree_02", "island_tree_03", "tree_small_02"]
	for i in big.size():
		var m := PHModels.node(big[i])
		m.position = Vector3(-10 + i * 7.5, 0, -5)
		m.scale = Vector3.ONE * PHModels.TREE_SCALE[i]
		stage.add_child(m)
	var pier: Node3D = load(DIR + "modular_wooden_pier.glb").instantiate()
	pier.position = Vector3(18, 0, 0)
	stage.add_child(pier)
	var ship: Node3D = load(DIR + "ship_pinnace.glb").instantiate()
	ship.position = Vector3(8, 0, -22)
	ship.scale = Vector3.ONE * 0.4
	stage.add_child(ship)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 45
	cam.position = Vector3(2, 9, 22)
	cam.look_at(Vector3(2, 1.5, 0))
	cam.current = true
	await wait_seconds(0.8)
	await screenshot("ph_front")
	cam.position = Vector3(2, 3, 11)
	cam.look_at(Vector3(-2, 0.4, 4))
	await wait_seconds(0.3)
	await screenshot("ph_close")
	cam.position = Vector3(18, 28, 26)
	cam.look_at(Vector3(4, 0, -4))
	await wait_seconds(0.3)
	await screenshot("ph_iso")
