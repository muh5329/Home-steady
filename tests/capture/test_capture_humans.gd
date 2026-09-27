extends TestCase
## Line-up of the humanoid bodies (characters/humans) in a neutral studio:
## scale, facing, materials and a few shared clips. `tools/capture.sh humans`


func test_capture_humans() -> void:
	var stage := Node3D.new()
	add_child(stage)
	_spawned.append(stage)
	var env := WorldEnvironment.new()
	env.environment = load("res://art/environments/default_environment.tres")
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor.mesh = plane
	floor.material_override = load("res://art/environments/materials/stylized_ground.tres")
	stage.add_child(floor)
	# Reference height: a 1.8 m post.
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 1.8, 0.1)
	post.mesh = box
	post.position = Vector3(-3.0, 0.9, 0)
	stage.add_child(post)
	var names := ["fighter", "ranger", "wizard", "peasant_m", "peasant_f", "peasant_m2", "noble_m"]
	var clips := [&"Idle_Combat", &"2H_Ranged_Aiming", &"Idle", &"Chopping", &"Idle", &"Idle", &"Talking"]
	var bodies: Array[Node3D] = []
	for i in names.size():
		var h: Node3D = load("res://characters/humans/%s.tscn" % names[i]).instantiate()
		stage.add_child(h)
		h.position = Vector3(-1.8 + i * 1.1, 0, 0)
		bodies.append(h)
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		ap.play(clips[i])
		var gear := {0: ["sword", "round_shield"], 1: ["crossbow", ""], 2: ["staff", ""], 3: ["woodaxe", ""], 5: ["pickaxe", ""]}
		if gear.has(i):
			ModelUtils.attach_to_bone(h, "handslot.r", load("res://art/props/weapons/%s.tscn" % gear[i][0]))
			if gear[i][1] != "":
				ModelUtils.attach_to_bone(h, "handslot.l", load("res://art/props/weapons/%s.tscn" % gear[i][1]))
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(1.5, 1.6, 6.5)
	cam.look_at(Vector3(1.5, 0.9, 0))
	cam.fov = 45
	cam.current = true
	await wait_seconds(0.6)
	await screenshot("humans_front")
	cam.position = Vector3(1.5, 12, 11)
	cam.look_at(Vector3(1.5, 0.5, 0))
	await wait_seconds(0.3)
	await screenshot("humans_iso")
	for b in bodies:
		b.rotation_degrees.y = 180
	cam.position = Vector3(1.5, 1.6, 6.5)
	cam.look_at(Vector3(1.5, 0.9, 0))
	await wait_seconds(0.3)
	await screenshot("humans_back")
