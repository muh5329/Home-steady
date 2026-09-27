extends Node3D
## The crypt's surface ruin: a roofless stone mausoleum of rough uneven
## brick (Medieval Village kit), a round-arched doorway into darkness at the
## back, vines over the walls and fallen masonry. The torches and the
## passage are scene nodes; the old dungeon-kit meshes are replaced here.

const OLD_PARTS: Array[StringName] = [&"Floor", &"BackDoor", &"WallLeft", &"WallRight",
	&"PillarL", &"PillarR", &"PillarBL", &"PillarBR", &"Banner", &"Rubble"]


func _ready() -> void:
	for part in OLD_PARTS:
		var n := get_node_or_null(NodePath(part)) as Node3D
		if n:
			n.visible = false
	var ruin := Node3D.new()
	ruin.name = "Ruin"
	add_child(ruin)
	_put(ruin, "Wall_UnevenBrick_Door_Round", Transform3D(Basis(), Vector3(0, 0, -2)))
	for z: float in [-1.0, 1.0]:
		_put(ruin, "Wall_UnevenBrick_Straight", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-2, 0, z)))
		_put(ruin, "Wall_UnevenBrick_Straight", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, z)))
	for x: float in [-2.0, 2.0]:
		for z: float in [-2.0, 2.0]:
			_put(ruin, "Corner_ExteriorWide_Brick", Transform3D(Basis(Vector3.UP, atan2(x, z) - PI * 0.25), Vector3(x, 0, z)))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_put(ruin, "Floor_UnevenBrick", Transform3D(Basis(), Vector3(x, 0.02, z)))
	_put(ruin, "Prop_Vine5", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2.25, 2.6, 0.3)))
	_put(ruin, "Prop_Vine2", Transform3D(Basis(), Vector3(-1.2, 3.0, -1.7)))
	_put(ruin, "Prop_Vine1", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-2.25, 2.8, 1.0)))
	for i in 6:
		var b := ["Prop_Brick1", "Prop_Brick2", "Prop_Brick3", "Prop_Brick4"][i % 4] as String
		_put(ruin, b, Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3.ONE * 1.6), Vector3(-3.2 + i * 0.35, 0.15, 2.4 + (i % 3) * 0.4)))
	# Darkness beyond the arch.
	var dark := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 2.6)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.01, 0.01, 0.012)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	dark.mesh = q
	dark.position = Vector3(0, 1.3, -2.2)
	ruin.add_child(dark)
	_overgrowth(ruin)
	# In daylight the torches glow but barely light the stone.
	for torch in [get_node_or_null(^"TorchL"), get_node_or_null(^"TorchR")]:
		var light := torch.get_node_or_null(^"Light") as OmniLight3D if torch else null
		if light:
			light.omni_range = 4.0
			if light.has_method(&"set_base_energy"):
				light.set_base_energy(0.5)
			else:
				light.light_energy = 0.5


## The ruin is dug into a mossy outcrop (scanned rock sets banked behind and
## beside it), with ferns, a fallen trunk and stumps pushing in, like the
## overgrown jungle ruin in the references.
func _overgrowth(ruin: Node3D) -> void:
	var rocks := [
		["rock_moss_set_01", Vector3(-4.2, -0.4, -3.2), 0.6, 2.2],
		["rock_moss_set_02", Vector3(4.4, -0.3, -2.8), 2.4, 2.4],
		["rock_moss_set_01", Vector3(0.6, -0.6, -5.6), 3.6, 2.6],
		["rock_moss_set_02", Vector3(-5.2, -0.3, 1.2), 1.4, 1.5],
		["rock_moss_set_02", Vector3(5.0, -0.3, 1.8), 4.4, 1.3],
	]
	# A weathered crag rising behind the tomb (scanned coastal rock, scaled
	# down), so the ruin reads as dug into a hillside.
	for c in [[Vector3(-2.5, -0.8, -8.5), 0.4, Vector3(3.4, 3.6, 3.0)], [Vector3(3.5, -0.8, -8.0), 2.9, Vector3(3.2, 3.0, 3.2)]]:
		var crag := PHModels.node("rock_moss_set_01" if c[1] < 1.0 else "rock_moss_set_02")
		crag.position = c[0]
		crag.rotation.y = c[1]
		crag.scale = c[2]
		ruin.add_child(crag)
	for r in rocks:
		var n := PHModels.node(r[0])
		n.position = r[1]
		n.rotation.y = r[2]
		n.scale = Vector3.ONE * float(r[3])
		ruin.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 16:
		var a := rng.randf() * TAU
		var d := rng.randf_range(2.8, 5.5)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if p.z > 1.5 and absf(p.x) < 1.8:
			continue  # keep the way in clear
		var fern := PHModels.node("fern_02", PackedStringArray(), false)
		fern.position = p
		fern.rotation.y = rng.randf() * TAU
		fern.scale = Vector3.ONE * rng.randf_range(1.3, 2.0)
		ruin.add_child(fern)
	var trunk := PHModels.node("dead_tree_trunk")
	trunk.position = Vector3(3.6, 0.05, 3.4)
	trunk.rotation.y = 0.5
	trunk.scale = Vector3.ONE * 1.2
	ruin.add_child(trunk)
	var stump := PHModels.node("tree_stump_01")
	stump.position = Vector3(-3.8, -0.05, 3.2)
	stump.scale = Vector3.ONE * 0.8
	ruin.add_child(stump)


func _put(parent: Node3D, piece: String, xf: Transform3D) -> void:
	if not ResourceLoader.exists(VillageKit.KIT + piece + ".fbx"):
		return
	var n := VillageKit.piece(piece)
	n.transform = xf
	parent.add_child(n)
