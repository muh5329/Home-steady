class_name DungeonBuilder
extends Node3D
## Turns a DungeonLayout into a playable space at runtime: floor and wall
## pieces (MultiMesh per piece type), collision, corner pillars, wall
## torches, props and enemy spawns. Put it under a NavigationRegion3D and
## the region is baked once the geometry exists.
##

signal built

const KIT := "res://art/third_party/kaykit/dungeon/%s.gltf.glb"
const TORCH_SCENE := preload("res://dungeons/props/wall_torch.tscn")
const WALL_HEIGHT := 4.0  # kit units
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

@export var layout: DungeonLayout
@export var navigation_region: NavigationRegion3D
## Sized to cover the whole layout (dark, torch-lit ambience inside).
@export var ambience_zone: AmbienceZone
## Floor pieces (first is the common one) and wall pieces, by kit name.
@export var floor_pieces: PackedStringArray = ["floor_tile_large", "floor_tile_large_rocks"]
@export var wall_pieces: PackedStringArray = ["wall", "wall_cracked"]
@export var corner_piece := "pillar"

var _transforms: Dictionary = {}  # piece name -> Array[Transform3D]
var _collision: StaticBody3D
var _pillars: Dictionary = {}  # Vector2i vertex -> true
var _mesh_cache: Dictionary = {}
var _is_built := false


func _ready() -> void:
	build()


func is_built() -> bool:
	return _is_built


## Cell centre in this node's space.
func cell_position(cell: Vector2i) -> Vector3:
	var cs := layout.cell_size
	return Vector3((cell.x + 0.5) * cs, 0.0, (cell.y + 0.5) * cs)


func cell_global(cell: Vector2i) -> Vector3:
	return to_global(cell_position(cell))


func build() -> void:
	if _is_built or layout == null:
		return
	_collision = StaticBody3D.new()
	_collision.name = "Collision"
	_collision.collision_layer = 1
	_collision.collision_mask = 0
	add_child(_collision)
	var size := layout.size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if layout.is_floor(cell):
				_build_cell(cell)
	_emit_multimeshes()
	_fit_ambience(size)
	_is_built = true
	if navigation_region:
		navigation_region.bake_navigation_mesh(false)
	built.emit()


# --- cells --------------------------------------------------------------------------------

func _build_cell(cell: Vector2i) -> void:
	var cs := layout.cell_size
	var s := layout.piece_scale
	var centre := cell_position(cell)
	var h := _hash(cell)
	# Floor.
	var piece := floor_pieces[0] if h % 5 != 0 or floor_pieces.size() < 2 else floor_pieces[1]
	if layout.at(cell) in layout.floor_supplied_by:
		piece = ""
	if piece != "":
			_add_piece(piece, Transform3D(Basis.from_euler(Vector3(0, (h % 4) * PI * 0.5, 0)).scaled(Vector3.ONE * s), centre))
	_add_box(Vector3(cs, 1.0, cs), centre + Vector3.DOWN * 0.5)
	# Walls where floor meets rock.
	for i in DIRS.size():
		var d := DIRS[i]
		if layout.is_floor(cell + d):
			continue
		var dir3 := Vector3(d.x, 0, d.y)
		var basis := Basis(Vector3.UP, 0.0 if d.x == 0 else PI * 0.5).scaled(Vector3.ONE * s)
		var wall := wall_pieces[0] if (h + i) % 7 != 0 or wall_pieces.size() < 2 else wall_pieces[1]
		_add_piece(wall, Transform3D(basis, centre + dir3 * cs * 0.5))
		var thick := 1.0 * s
		var box := Vector3(cs + thick, WALL_HEIGHT * s, thick) if d.x == 0 else Vector3(thick, WALL_HEIGHT * s, cs + thick)
		_add_box(box, centre + dir3 * cs * 0.5 + Vector3.UP * WALL_HEIGHT * s * 0.5)
		if (_hash(cell * 3 + d) % layout.torch_spacing) == 0:
			_add_torch(centre + dir3 * (cs * 0.5 - 0.4 * s), -dir3)
	_add_corner_pillars(cell)
	# Contents.
	var symbol := layout.at(cell)
	if layout.props.has(symbol):
		_add_prop(layout.props[symbol], cell)
	elif layout.enemies.has(symbol):
		_add_spawn(layout.enemies[symbol], cell)


## Pillars hide the seams where walls meet (inner and outer corners).
func _add_corner_pillars(cell: Vector2i) -> void:
	for i in 4:
		var a := DIRS[i]
		var b := DIRS[(i + 1) % 4]
		var wall_a := not layout.is_floor(cell + a)
		var wall_b := not layout.is_floor(cell + b)
		var diagonal := layout.is_floor(cell + a + b)
		if (wall_a and wall_b) or (not wall_a and not wall_b and not diagonal):
			# Vertex between this cell and the a/b neighbours.
			var vertex := cell * 2 + Vector2i(1, 1) + a + b
			if _pillars.has(vertex):
				continue
			_pillars[vertex] = true
			var cs := layout.cell_size
			var pos := Vector3(vertex.x * cs * 0.5, 0, vertex.y * cs * 0.5)
			_add_piece(corner_piece, Transform3D(Basis().scaled(Vector3.ONE * layout.piece_scale), pos))
			_add_box(Vector3(1.2, WALL_HEIGHT, 1.2) * layout.piece_scale, pos + Vector3.UP * WALL_HEIGHT * layout.piece_scale * 0.5)


func _add_torch(pos: Vector3, facing: Vector3) -> void:
	var t: Node3D = TORCH_SCENE.instantiate()
	add_child(t)
	t.position = pos + Vector3.UP * 2.1 * layout.piece_scale
	t.rotation.y = atan2(facing.x, facing.z)
	t.scale = Vector3.ONE * layout.piece_scale


## Props face the room: back against a wall, front toward open floor.
func _add_prop(scene: PackedScene, cell: Vector2i) -> void:
	var node: Node3D = scene.instantiate()
	var facing := _room_facing(cell)
	# Stable, cell-based names: props persist by node path (chests, gates).
	node.name = "%s_%d_%d" % [node.name, cell.x, cell.y]
	add_child(node)
	node.position = cell_position(cell)
	node.rotation.y = atan2(facing.x, facing.z)


## Direction from `cell` into the room: away from a wall that has open
## floor opposite it; otherwise toward any open neighbour.
func _room_facing(cell: Vector2i) -> Vector3:
	for d in DIRS:
		if not layout.is_floor(cell + d) and layout.is_floor(cell - d):
			return -Vector3(d.x, 0, d.y)
	for d in DIRS:
		if layout.is_floor(cell + d):
			return Vector3(d.x, 0, d.y)
	return Vector3.BACK


func _add_spawn(definition: EnemyDefinition, cell: Vector2i) -> void:
	var spawn := EnemySpawn.new()
	spawn.definition = definition
	spawn.name = "Spawn_%d_%d" % [cell.x, cell.y]
	add_child(spawn)
	spawn.position = cell_position(cell)
	spawn.rotation.y = (_hash(cell) % 8) * PI * 0.25


func _fit_ambience(size: Vector2i) -> void:
	if ambience_zone == null:
		return
	var extent := Vector3(size.x * layout.cell_size, 12.0, size.y * layout.cell_size)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent + Vector3(4, 0, 4)
	shape.shape = box
	ambience_zone.add_child(shape)
	ambience_zone.global_position = to_global(Vector3(extent.x * 0.5, 4.0, extent.z * 0.5))


# --- geometry helpers -------------------------------------------------------------------------

func _add_piece(piece: String, t: Transform3D) -> void:
	if not _transforms.has(piece):
		_transforms[piece] = []
	_transforms[piece].append(t)


func _add_box(size: Vector3, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	_collision.add_child(shape)


func _emit_multimeshes() -> void:
	for piece in _transforms:
		var parts := _mesh_parts(piece)
		var list: Array = _transforms[piece]
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i] * part["offset"])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_mm" % piece
			mmi.multimesh = mm
			add_child(mmi)


## Meshes of a kit piece with their offsets inside the piece.
func _mesh_parts(piece: String) -> Array:
	if _mesh_cache.has(piece):
		return _mesh_cache[piece]
	var parts := []
	var path := KIT % piece
	if not ResourceLoader.exists(path):
		push_warning("DungeonBuilder: no kit piece '%s'" % piece)
		_mesh_cache[piece] = parts
		return parts
	var root: Node3D = load(path).instantiate()
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var offset := Transform3D()
		var n: Node = m
		while n != root:
			offset = (n as Node3D).transform * offset
			n = n.get_parent()
		parts.append({"mesh": m.mesh, "offset": offset})
	root.free()
	_mesh_cache[piece] = parts
	return parts


static func _hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663))
