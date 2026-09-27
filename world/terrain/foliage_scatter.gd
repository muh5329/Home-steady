class_name FoliageScatter
extends Node3D
## Fills the land Fabledom-style: windblown grass tufts everywhere except
## roads, plazas and under things; wildflower drifts; a dense pine belt at
## the edge of the play area and a forest to the horizon. Grass is built in
## chunks (nearest first, a few per frame) with a visibility range, and
## rebuilt when buildings change the ground.

@export var play_rect := Rect2(-76, -76, 152, 152)
@export var chunk_size := 8.0
@export var grass_per_m2 := 2.3
@export var grass_view_distance := 48.0
@export var flower_colors: PackedColorArray = [Color(1.0, 0.86, 0.3), Color(0.98, 0.96, 0.9), Color(0.5, 0.62, 1.0), Color(0.95, 0.55, 0.7)]
@export var flower_patch_threshold := 0.62
## Pine belt: trees between this inset from the play edge and the edge.
@export var belt_depth := 18.0
@export var belt_trees := 420
@export var far_trees := 520
@export var far_radius := Vector2(90.0, 220.0)
@export var tree_scale := Vector2(7.0, 12.0)
@export var chunks_per_frame := 10
@export var random_seed := 3

## Belt trees this close to the play area are full scanned trees (PHModels);
## the rest of the belt and the far forest stay light card trees.
@export var scanned_band := 9.0

## Pines per summit of each terraced hill.
@export var hilltop_trees := Vector2i(3, 7)

const BUSHES := ["bush_01", "bush_03", "bush_03"]

var _pending: Array[Vector2i] = []
var _clumps := FastNoiseLite.new()
var _chunks: Dictionary = {}  # Vector2i -> Node3D
var _noise := FastNoiseLite.new()
var _painter: TerrainPainter


func _ready() -> void:
	# Other terrain (painter, hills) must exist first.
	_start.call_deferred()
	set_process(false)


func _start() -> void:
	# Rivers and set dressing paint their banks and lanes deferred too.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_noise.seed = random_seed
	_noise.frequency = 0.035
	_clumps.seed = random_seed + 5
	_clumps.frequency = 0.07
	_painter = TerrainPainter.of(self)
	_build_forest()
	_queue_all()
	EventBus.world_geometry_changed.connect(_queue_all)


func is_complete() -> bool:
	return _pending.is_empty()


func _queue_all() -> void:
	var nx := int(ceil(play_rect.size.x / chunk_size))
	var ny := int(ceil(play_rect.size.y / chunk_size))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var centre := Vector2(player.global_position.x, player.global_position.z) if player else Vector2.ZERO
	_pending.clear()
	for y in ny:
		for x in nx:
			_pending.append(Vector2i(x, y))
	_pending.sort_custom(func(a, b): return _chunk_centre(a).distance_squared_to(centre) > _chunk_centre(b).distance_squared_to(centre))
	set_process(true)


func _process(_delta: float) -> void:
	for i in chunks_per_frame:
		if _pending.is_empty():
			set_process(false)
			return
		_build_chunk(_pending.pop_back())


func _chunk_centre(c: Vector2i) -> Vector2:
	return play_rect.position + (Vector2(c) + Vector2(0.5, 0.5)) * chunk_size


# --- grass and flowers ---------------------------------------------------------------------

func _build_chunk(c: Vector2i) -> void:
	if _chunks.has(c):
		_chunks[c].queue_free()
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(root)
	_chunks[c] = root
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + random_seed
	var origin := play_rect.position + Vector2(c) * chunk_size
	var grass: Array[Transform3D] = []
	var tall: Array[Transform3D] = []
	var bushes: Array = [[], [], []]
	var flowers: Array = []
	for i in flower_colors.size():
		flowers.append([])
	var space := get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1 | 16 | 32
	q.collide_with_areas = true
	# Twice the average density is tried; clumping noise keeps some of it:
	# open lawn stays sparse, drifts and edges grow thick.
	var count := int(chunk_size * chunk_size * grass_per_m2 * 2.0)
	for i in count:
		var p := origin + Vector2(rng.randf(), rng.randf()) * chunk_size
		var pos := Vector3(p.x, 0.0, p.y)
		var cover := _painter.coverage(pos) if _painter else 0.0
		if cover > 0.05 or River.covered(self, pos):
			continue  # roads, plazas, beaches and water stay clean
		var edge := _painter != null and _near_path(pos)
		var clump := _clumps.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		if rng.randf() > lerpf(0.25, 0.85, clump) and not edge:
			continue
		q.position = pos + Vector3.UP * 0.4
		if not space.intersect_point(q, 1).is_empty():
			continue
		# Shrubs: along roads, in the densest drifts, and hugging buildings.
		var bush_chance := 0.014 if edge else (0.005 if clump > 0.8 else 0.0)
		if rng.randf() < 0.05 and _near_building(space, pos):
			bush_chance = 0.4
		if rng.randf() < bush_chance:
			var bs := rng.randf_range(0.4, 0.6)
			bushes[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bs, bs * rng.randf_range(0.8, 1.1), bs)), pos))
			continue
		# Tall meadow tufts: thick along the ways, scattered in lush drifts.
		if rng.randf() < (0.35 if edge else (0.1 if clump > 0.7 else 0.0)):
			var ts := rng.randf_range(0.8, 1.25)
			tall.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ts, ts * rng.randf_range(0.85, 1.15), ts)), pos))
			continue
		var s := rng.randf_range(0.85, 1.2) * (1.35 if edge else 1.0)
		var patch := _noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * lerpf(0.8, 1.3, patch), s))
		grass.append(Transform3D(basis, pos))
		if (patch > flower_patch_threshold and rng.randf() < 0.28) or (edge and rng.randf() < 0.3):
			var kind := int(absf(_noise.get_noise_2d(p.x * 0.3 + 100.0, p.y * 0.3)) * 7.0) % flower_colors.size()
			flowers[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)), pos))
	_emit(root, FoliageCards.plant("grass_card.png", Vector2(0.75, 0.55), 3, Color(0.95, 1.0, 0.85)), grass, grass_view_distance)
	_emit(root, FoliageCards.plant("grass_dry_card.png", Vector2(0.8, 0.85), 2, Color(1.05, 1.0, 0.85)), tall, grass_view_distance * 1.1)
	# Bushes are small scanned broadleaf trees cut down to a leafy crown.
	for v in 3:
		for i in bushes[v].size():
			var xf: Transform3D = bushes[v][i]
			bushes[v][i] = Transform3D(xf.basis, xf.origin - Vector3.UP * 0.25 * xf.basis.get_scale().y)
		PHModels.emit(root, BUSHES[v], bushes[v], grass_view_distance * 1.1, true)
	for k in flower_colors.size():
		var flower_mesh: Mesh
		match k % 4:
			0: flower_mesh = FoliageCards.plant("flower_card.png", Vector2(0.55, 0.5), 2)
			1: flower_mesh = FoliageCards.plant("fern_card.png", Vector2(0.8, 0.65), 3)
			2: flower_mesh = FoliageMeshes.flower(Color(0.97, 0.96, 0.92))
			_: flower_mesh = FoliageMeshes.flower(Color(0.66, 0.55, 0.85))
		_emit(root, flower_mesh, flowers[k], grass_view_distance * 0.8)


## Right beside a building's footprint (layer 6).
func _near_building(space: PhysicsDirectSpaceState3D, pos: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = Footprint.LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for o in [Vector3(1.8, 0.4, 0), Vector3(-1.8, 0.4, 0), Vector3(0, 0.4, 1.8), Vector3(0, 0.4, -1.8)]:
		q.position = pos + o
		if not space.intersect_point(q, 1).is_empty():
			return true
	return false


## Just off a road or plaza (tall grass and flowers line the ways).
func _near_path(pos: Vector3) -> bool:
	for o in [Vector3(1.6, 0, 0), Vector3(-1.6, 0, 0), Vector3(0, 0, 1.6), Vector3(0, 0, -1.6)]:
		if _painter.coverage(pos + o) > 0.3:
			return true
	return false


func _emit(parent: Node3D, mesh: Mesh, xforms: Array, view: float, shadows := false) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if view > 0.0:
		mmi.visibility_range_end = view
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)


# --- forest ------------------------------------------------------------------------------------

func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed * 97
	var variants: Array = [[], [], []]
	var space := get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1 | 16 | 32
	q.collide_with_areas = true
	var body := StaticBody3D.new()
	body.name = "ForestColliders"
	body.collision_mask = 0
	add_child(body)
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.5
	trunk.height = 4.0
	var inner := play_rect.grow(-belt_depth)
	var scanned: Array = []
	for t in PHModels.TREES:
		scanned.append([])
	var belt_bushes: Array = [[], [], []]
	var placed := 0
	var tries := 0
	while placed < belt_trees and tries < belt_trees * 8:
		tries += 1
		var p := play_rect.position + Vector2(rng.randf(), rng.randf()) * play_rect.size
		if inner.has_point(p):
			continue
		var pos := Vector3(p.x, 0, p.y)
		if (_painter and _painter.coverage(pos) > 0.05) or River.covered(self, pos, 2.0):
			continue
		q.position = pos + Vector3.UP * 0.5
		if not space.intersect_point(q, 1).is_empty():
			continue
		if _edge_distance(inner, p) < scanned_band:
			var v := rng.randi() % scanned.size()
			scanned[v].append(_scanned_xform(rng, pos, v))
		else:
			variants[placed % 3].append(_tree_xform(rng, pos))
		if rng.randf() < 0.45:
			var off := Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
			var bs := rng.randf_range(1.0, 1.8)
			belt_bushes[placed % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * bs), pos + off))
		var cs := CollisionShape3D.new()
		cs.shape = trunk
		cs.position = pos + Vector3.UP * 2.0
		body.add_child(cs)
		placed += 1
	for i in far_trees:
		var a := rng.randf() * TAU
		var r := rng.randf_range(far_radius.x, far_radius.y)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		# Leave the southern approach open (the road in), and the river.
		if (pos.z > 60.0 and absf(pos.x) < 14.0) or River.covered(self, pos, 3.0):
			continue
		variants[i % 3].append(_tree_xform(rng, pos, 1.25))
	for hills in get_tree().get_nodes_in_group(TerraceHills.GROUP):
		for top: Vector4 in hills.tops:
			for i in rng.randi_range(hilltop_trees.x, hilltop_trees.y):
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf()) * top.w
				var pos := Vector3(top.x + cos(a) * r, top.y, top.z + sin(a) * r)
				var v := rng.randi() % scanned.size()
				scanned[v].append(_scanned_xform(rng, pos, v, 0.9))
	for v in scanned.size():
		_emit_chunked(PHModels.TREES[v], scanned[v])
	for v in 3:
		_emit(self, FoliageCards.tree(v), variants[v], 0.0, true)
		_emit(self, FoliageCards.shrub(v), belt_bushes[v], 90.0)


func _tree_xform(rng: RandomNumberGenerator, pos: Vector3, bigger := 1.0) -> Transform3D:
	var s := rng.randf_range(tree_scale.x, tree_scale.y) * bigger
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
	return Transform3D(basis, pos)


func _scanned_xform(rng: RandomNumberGenerator, pos: Vector3, v: int, bigger := 1.0) -> Transform3D:
	var s: float = PHModels.TREE_SCALE[v] * rng.randf_range(0.85, 1.25) * bigger
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
	return Transform3D(basis, pos - Vector3.UP * 0.06 * s)


## Distance from a point outside `inner` to its edge.
func _edge_distance(inner: Rect2, p: Vector2) -> float:
	var c := p.clamp(inner.position, inner.end)
	return c.distance_to(p)


## Scanned trees are heavy, so they go out in 24 m cells: each cell is its own
## MultiMesh and is culled and LOD'd on its own.
func _emit_chunked(model: String, xforms: Array, cell := 24.0) -> void:
	var cells := {}
	for xf: Transform3D in xforms:
		var k := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(xf)
	for k in cells:
		PHModels.emit(self, model, cells[k], 0.0, true)
