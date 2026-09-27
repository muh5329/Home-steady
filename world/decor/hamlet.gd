class_name Hamlet
extends Node3D
## Set dressing: a lived-in riverside hamlet built from kit houses, with
## cobbled lanes, garden walls and fences, props and quayside piers. Purely
## visual (it sits where the player can't walk), so it has no collision and
## no navigation cost.

## Houses: x, z, yaw (degrees), packed size (w * 10 + d), floors * 10 + style.
@export var houses: PackedFloat32Array = []
## Lanes: each is a list of (x, z) points; separate lanes with NAN.
@export var lanes: PackedVector2Array = []
@export var lane_width := 3.5
## Piers: x, z, yaw, length.
@export var piers: PackedFloat32Array = []
## Boats: x, z, yaw.
@export var boats: PackedFloat32Array = []
## Wharves (plank quays full of cargo): x, z, yaw, length (along local Z),
## width (local X, the water side is +X).
@export var wharves: PackedFloat32Array = []
## Moored ships: x, z, yaw, scale (the scanned pinnace is ~40 m long).
@export var ships: PackedFloat32Array = []
## Clutter: kind (PropModel.Kind), x, z, yaw.
@export var props: PackedFloat32Array = []
## Trees: x, z, variant (PHModels.TREES), scale (10 = typical).
@export var trees: PackedFloat32Array = []
@export var water_level := -0.3


func _ready() -> void:
	(func():
		var painter := TerrainPainter.of(self)
		if painter == null:
			return
		var lane := PackedVector2Array()
		for pt in lanes:
			if is_nan(pt.x):
				painter.paint_polyline(lane, lane_width, PaintStroke.Kind.COBBLE)
				lane = PackedVector2Array()
			else:
				lane.append(pt)
		if lane.size() > 1:
			painter.paint_polyline(lane, lane_width, PaintStroke.Kind.COBBLE)
		# Bare earth under the wharves (keeps grass from growing through).
		for i in range(0, wharves.size(), 5):
			var c := Vector2(wharves[i], wharves[i + 1])
			var dir := Vector2(0, 1).rotated(-deg_to_rad(wharves[i + 2]))
			var half := dir * wharves[i + 3] * 0.5
			painter.paint_polyline(PackedVector2Array([c - half, c + half]), wharves[i + 4] + 0.6, PaintStroke.Kind.ROAD)).call_deferred()
	_build()


## Houses go up one per frame so loading the level doesn't stall.
func _build() -> void:
	for i in range(0, houses.size(), 5):
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var h := KitHouse.new()
		var size := int(houses[i + 3])
		var fs := int(houses[i + 4])
		h.width_cells = size / 10
		h.depth_cells = size % 10
		h.floors = fs / 10
		h.style = fs % 10
		h.random_seed = i * 7 + 3
		h.position = Vector3(houses[i], 0, houses[i + 1])
		h.rotation_degrees.y = houses[i + 2]
		add_child(h)
		if h.chimney_top != null and randf() < 0.7:
			var smoke: Node3D = load("res://art/vfx/smoke_plume.tscn").instantiate()
			smoke.position = h.transform * (h.chimney_top as Vector3)
			add_child(smoke)
	for i in range(0, piers.size(), 4):
		add_child(pier(piers[i + 3], Vector3(piers[i], 0.4, piers[i + 1]), piers[i + 2]))
	for i in range(0, wharves.size(), 5):
		add_child(wharf(Vector3(wharves[i], 0.0, wharves[i + 1]), wharves[i + 2], wharves[i + 3], wharves[i + 4], i))
	for i in range(0, ships.size(), 4):
		var ship := PHModels.node("ship_pinnace")
		ship.scale = Vector3.ONE * ships[i + 3]
		ship.position = Vector3(ships[i], water_level - 0.2 * ships[i + 3] / 0.3, ships[i + 1])
		ship.rotation_degrees = Vector3(0, ships[i + 2], 1.5)
		add_child(ship)
	for i in range(0, boats.size(), 3):
		var b := PropModel.new()
		b.kind = PropModel.Kind.ROWBOAT
		b.position = Vector3(boats[i], water_level - 0.28, boats[i + 1])
		b.rotation_degrees = Vector3(randf_range(-2, 2), boats[i + 2], randf_range(-3, 3))
		add_child(b)
	for i in range(0, props.size(), 4):
		var p := PropModel.new()
		p.kind = int(props[i]) as PropModel.Kind
		p.position = Vector3(props[i + 1], 0, props[i + 2])
		p.rotation_degrees.y = props[i + 3]
		add_child(p)
	var trunks := StaticBody3D.new()
	trunks.collision_mask = 0
	add_child(trunks)
	for i in range(0, trees.size(), 4):
		var shape := CylinderShape3D.new()
		shape.radius = 0.35
		shape.height = 3.0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(trees[i], 1.5, trees[i + 1])
		trunks.add_child(cs)
		# Scanned trees; the stored scale is relative to 10 (a typical tree).
		var v := int(trees[i + 2]) % PHModels.TREES.size()
		var s: float = PHModels.TREE_SCALE[v] * trees[i + 3] / 10.0
		var t := PHModels.node(PHModels.TREES[v])
		t.scale = Vector3.ONE * s
		t.position = Vector3(trees[i], -0.06 * s, trees[i + 1])
		t.rotation.y = randf() * TAU
		add_child(t)


## A weathered scanned pier (Poly Haven modular_wooden_pier) about `length`
## metres long, centred on `deck` (the deck's top) and running along its
## local Z. Three sections or more get the cargo-hoist frame.
static func pier(length: float, deck: Vector3, yaw: float) -> Node3D:
	const PITCH := 2.95
	var n := clampi(roundi(length / PITCH), 1, 4)
	var names := PackedStringArray()
	for k in n:
		names.append("section_0%d" % (k + 1))
	if n >= 3:
		names.append("section_05")
	var root := Node3D.new()
	root.name = "Pier"
	root.position = deck
	root.rotation_degrees.y = yaw
	var model := PHModels.node("modular_wooden_pier", names)
	model.position = Vector3(0, -2.65, -(0.43 - n * PITCH * 0.5))
	root.add_child(model)
	return root


## A plank quay on posts, deck at 0.35 m, piled with barrels, crates and
## sacks like a working harbour. Walkable (the deck has a collider).
static func wharf(at: Vector3, yaw: float, length: float, width: float, seed: int) -> Node3D:
	const DECK := 0.35
	var root := Node3D.new()
	root.name = "Wharf"
	root.position = at
	root.rotation_degrees.y = yaw
	var parts := {}
	var deck := WeaponModel._st(parts, "deck")
	var n := int(length / 0.28)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		var jitter := sin(i * 12.9898) * 0.012
		WeaponModel._box(deck, Vector3(0, DECK - 0.04 + jitter, z), Vector3(width, 0.08, length / n - 0.02))
	var posts := WeaponModel._st(parts, "posts")
	for i in int(length / 1.8) + 1:
		var z := -length * 0.5 + i * length / maxi(int(length / 1.8), 1)
		for x: float in [-width * 0.5 + 0.12, width * 0.5 - 0.12]:
			WeaponModel._cyl(posts, Vector3(x, -2.2, z), Vector3(x, DECK + (0.55 if x > 0.0 else -0.02), z), 0.13, 0.12, 8)
	# A low kerb beam on the water side.
	WeaponModel._box(posts, Vector3(width * 0.5 - 0.12, DECK + 0.08, 0), Vector3(0.16, 0.16, length))
	var mesh := ArrayMesh.new()
	for key in parts:
		var st: SurfaceTool = parts[key]
		st.generate_tangents()
		st.commit(mesh)
		var m := StandardMaterial3D.new()
		m.uv1_triplanar = true
		m.normal_enabled = true
		m.roughness = 0.9
		if key == "deck":
			m.albedo_texture = load("res://art/third_party/polyhaven/tex/weathered_planks_diff.jpg")
			m.normal_texture = load("res://art/third_party/polyhaven/tex/weathered_planks_nor_gl.jpg")
			# Sun- and salt-bleached boards.
			m.albedo_color = Color(1.45, 1.3, 1.12)
			m.uv1_scale = Vector3.ONE * 0.45
		else:
			m.albedo_texture = load("res://art/third_party/polyhaven/tex/wood_planks_dirt_diff.jpg")
			m.normal_texture = load("res://art/third_party/polyhaven/tex/wood_planks_dirt_nor_gl.jpg")
			m.albedo_color = Color(0.75, 0.65, 0.58)
			m.uv1_scale = Vector3.ONE * 0.8
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.3, length)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, DECK - 0.15, 0)
	body.add_child(cs)
	root.add_child(body)
	# A cargo hoist frame on the water side (from the scanned pier set).
	var hoist := Node3D.new()
	hoist.position = Vector3(width * 0.5 - 0.35, DECK, length * 0.18)
	hoist.rotation.y = PI * 0.5
	root.add_child(hoist)
	var frame := PHModels.node("modular_wooden_pier", PackedStringArray(["section_05"]))
	frame.position = Vector3(0, -2.65, 6.0)
	hoist.add_child(frame)
	# Cargo in stacks along the quay, leaving a lane down the middle.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var z := -length * 0.5 + 1.2
	while z < length * 0.5 - 1.0:
		var x := rng.randf_range(-width * 0.5 + 0.8, width * 0.5 - 1.0)
		if absf(x) < 0.9:
			x = signf(x + 0.01) * 1.2
		_cargo(root, Vector3(x, DECK, z), rng)
		z += rng.randf_range(1.6, 3.2)
	return root


static func _cargo(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	match rng.randi() % 4:
		0:  # a block of standing barrels
			for k in rng.randi_range(2, 4):
				var b := PropModel.new()
				b.kind = PropModel.Kind.BARREL
				b.position = at + Vector3((k % 2) * 0.78, 0, (k / 2) * 0.78)
				b.rotation.y = rng.randf() * TAU
				root.add_child(b)
		1:  # crates, some stacked
			for k in rng.randi_range(1, 3):
				var c := PHModels.node("wooden_crate_02")
				c.position = at + Vector3(k * 0.6, 0, rng.randf_range(-0.1, 0.1))
				c.rotation.y = rng.randf_range(-0.15, 0.15)
				root.add_child(c)
				if rng.randf() < 0.45:
					var top := PHModels.node("wooden_crate_02")
					top.position = c.position + Vector3(0, 0.47, 0)
					top.rotation.y = rng.randf_range(-0.2, 0.2)
					root.add_child(top)
		2:  # sacks around a lying barrel
			var lb := PropModel.new()
			lb.kind = PropModel.Kind.BARREL_LYING
			lb.position = at
			lb.rotation.y = rng.randf() * TAU
			root.add_child(lb)
			for k in 3:
				var sk := PropModel.new()
				sk.kind = PropModel.Kind.SACK
				sk.position = at + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(0.6, 1.0))
				sk.rotation.y = rng.randf() * TAU
				root.add_child(sk)
		_:  # the old barrel pair from the scans
			var bb := PHModels.node("wooden_barrels_01", PackedStringArray(["barrel0"]))
			bb.position = at + Vector3(0.1, 0, 1.9)
			bb.rotation.y = rng.randf_range(-0.3, 0.3)
			root.add_child(bb)
