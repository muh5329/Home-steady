class_name RoadsideClutter
extends Node3D
## Lived-in set dressing along the painted roads: every so often a little
## cluster of barrels, crates, sacks, logs or a bench stands just off the
## verge, alternating sides. Visual only (no collision, no navigation), so
## it never gets in anyone's way.

@export var spacing := 5.5
@export var offset := 2.6
@export var random_seed := 5
## Road strokes to follow (children of the TerrainPainter by name).
@export var roads: PackedStringArray = ["RoadMain", "RoadEast", "RoadWest", "RoadFarm"]

const KINDS := [PropModel.Kind.BARREL, PropModel.Kind.BARREL, PropModel.Kind.CRATE,
	PropModel.Kind.SACK, PropModel.Kind.SACK, PropModel.Kind.BARREL_LYING, PropModel.Kind.LOG_BUNDLE,
	PropModel.Kind.BUCKET, PropModel.Kind.CRATE]


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var painter := TerrainPainter.of(self)
	if painter == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var side := 1.0
	for road_name in roads:
		var stroke := painter.get_node_or_null(NodePath(road_name)) as PaintStroke
		if stroke == null:
			continue
		var total := stroke.curve.get_baked_length()
		var d := spacing * rng.randf_range(0.3, 1.0)
		while d < total:
			var p := stroke.to_global(stroke.curve.sample_baked(d))
			var ahead := stroke.to_global(stroke.curve.sample_baked(minf(d + 0.5, total)))
			var dir := (ahead - p).normalized()
			var normal := Vector3(-dir.z, 0, dir.x) * side
			var at := p + normal * (stroke.width * 0.5 + offset)
			side = -side
			d += spacing * rng.randf_range(0.8, 1.5)
			if painter.coverage(at) > 0.3 or River.covered(self, at, 1.0):
				continue
			if Vector2(at.x, at.z).distance_to(Vector2(0, 6)) < 5.0:
				continue  # keep the spawn clear
			if rng.randf() < 0.2:
				continue
			_cluster(at, dir, rng)


func _cluster(at: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(2, 4)
	var yaw := atan2(along.x, along.z)
	var roll := rng.randf()
	# Toward the crypt the verge grows wild and strewn with old masonry.
	if at.z < -18.0:
		roll *= 0.4
		if rng.randf() < 0.5:
			_rubble(at, rng)
	if roll < 0.3:
		_nature(at, rng)
		return
	if roll < 0.44:
		var bench := PropModel.new()
		bench.kind = PropModel.Kind.BENCH
		bench.position = at
		bench.rotation.y = yaw + PI * 0.5
		add_child(bench)
		return
	for i in count:
		var p := PropModel.new()
		p.kind = KINDS[rng.randi() % KINDS.size()]
		p.position = at + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		p.rotation.y = rng.randf() * TAU
		add_child(p)
		# Now and then a crate sits on a crate, a sack on a barrel.
		if p.kind == PropModel.Kind.CRATE and rng.randf() < 0.4:
			var top := PropModel.new()
			top.kind = PropModel.Kind.CRATE if rng.randf() < 0.5 else PropModel.Kind.SACK
			top.position = p.position + Vector3(rng.randf_range(-0.08, 0.08), 0.6, rng.randf_range(-0.08, 0.08))
			top.rotation.y = rng.randf() * TAU
			add_child(top)


## A scrap of wild verge from the scans: a stump, a mossy rock or a fallen
## trunk, with ferns around it.
func _nature(at: Vector3, rng: RandomNumberGenerator) -> void:
	var anchor: Node3D
	match rng.randi() % 3:
		0:
			anchor = PHModels.node("tree_stump_01")
			anchor.scale = Vector3.ONE * rng.randf_range(0.6, 0.85)
		1:
			var rock := MeshInstance3D.new()
			rock.mesh = load("res://art/foliage/boulder_model.gd").rock(rng.randi(), rng.randf_range(0.8, 1.4))
			anchor = rock
		_:
			anchor = PHModels.node("dead_tree_trunk")
			anchor.scale = Vector3.ONE * rng.randf_range(0.8, 1.1)
	anchor.position = at
	anchor.rotation.y = rng.randf() * TAU
	add_child(anchor)
	for i in rng.randi_range(2, 4):
		var fern := PHModels.node("fern_02", PackedStringArray(), false)
		var a := rng.randf() * TAU
		fern.position = at + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.3)
		fern.rotation.y = rng.randf() * TAU
		fern.scale = Vector3.ONE * rng.randf_range(1.0, 1.6)
		add_child(fern)


## Fallen masonry from the kit: a few scattered bricks and a broken block.
func _rubble(at: Vector3, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(3, 6):
		var piece := ["Prop_Brick1", "Prop_Brick2", "Prop_Brick3", "Prop_Brick4"][rng.randi() % 4] as String
		if not ResourceLoader.exists(VillageKit.KIT + piece + ".fbx"):
			return
		var b := VillageKit.piece(piece)
		b.position = at + Vector3(rng.randf_range(-1.4, 1.4), 0.08, rng.randf_range(-1.4, 1.4))
		b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		b.scale = Vector3.ONE * rng.randf_range(1.2, 1.8)
		add_child(b)
