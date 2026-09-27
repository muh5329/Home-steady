@tool
class_name KitHouse
extends Node3D
## A house assembled from the Quaternius Medieval Village MegaKit on its
## 2 m grid: stone or plaster ground floor with a door and windows, an
## optional timber-framed upper storey, a round-tile gable roof with brick
## gable ends and a chimney. The footprint is centred on the origin; the
## front (door side) faces +Z.

@export_range(2, 6) var width_cells := 3:  ## along X
	set(v):
		width_cells = v
		_queue_rebuild()
@export_range(2, 7) var depth_cells := 3:  ## along Z
	set(v):
		depth_cells = v
		_queue_rebuild()
@export_range(1, 2) var floors := 2:
	set(v):
		floors = v
		_queue_rebuild()
## 0 = plaster over a brick plinth, 1 = rough stone ground floor with a
## plaster upper storey, 2 = timber-framed plaster throughout.
@export_range(0, 2) var style := 1:
	set(v):
		style = v
		_queue_rebuild()
@export var chimney := true:
	set(v):
		chimney = v
		_queue_rebuild()
@export var random_seed := 1:
	set(v):
		random_seed = v
		_queue_rebuild()

const CELL := 2.0
const STOREY := 3.0

var _pending := false
## Local position of the chimney's top (for smoke), or null.
var chimney_top: Variant = null


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	(func():
		_pending = false
		rebuild()).call_deferred()


func rebuild() -> void:
	# Fade out when it stands between the camera and the hero.
	add_to_group(CameraOcclusion.GROUP)
	set_meta(&"fade_center", Vector3(0, floors * STOREY * 0.6, 0))
	set_meta(&"fade_radius", maxf(width_cells, depth_cells) * CELL * 0.6)
	for c in get_children():
		if c.has_meta(&"kit"):
			c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var hw := width_cells * CELL * 0.5
	var hd := depth_cells * CELL * 0.5
	for level in floors:
		var y := level * STOREY
		var ground := level == 0
		var family := _family(ground)
		# Walls around the perimeter: front (+Z), back (-Z), sides (±X).
		for side in 4:
			var cells := width_cells if side < 2 else depth_cells
			var door_at := cells / 2 if ground and side == 0 else -1
			for i in cells:
				var along := -((cells * CELL) * 0.5) + CELL * (i + 0.5)
				var piece := family + "_Straight"
				var window := ""
				if i == door_at:
					piece = family + "_Door_Flat"
				elif rng.randf() < (0.45 if ground else 0.6):
					var wide := rng.randf() < 0.5
					piece = family + ("_Window_Wide_Flat" if wide else "_Window_Thin_Round")
					window = "Window_Wide_Flat1" if wide else "Window_Thin_Round1"
				elif family == "Wall_Plaster" and not ground and rng.randf() < 0.5:
					piece = "Wall_Plaster_WoodGrid"
				var xf := _edge_transform(side, along, y, hw, hd)
				_place(piece, xf)
				if window != "":
					_place(window, xf)
					if rng.randf() < 0.6:
						var shutter := "WindowShutters_Wide_Flat_Open" if window.begins_with("Window_Wide") else "WindowShutters_Thin_Round_Open"
						_place(shutter, xf)
				if piece.ends_with("_Door_Flat"):
					_place("Door_1_Flat", xf * Transform3D(Basis(), Vector3(-0.5, 0, -0.1)))
					_dress_door(xf, rng)
				# Lived-in touch: an upper-floor balcony under some windows.
				if not ground and window != "" and side < 2 and rng.randf() < 0.3:
					_place("Balcony_Simple_Straight", xf)
		# Corner posts.
		var corner := "Corner_Exterior_Brick" if ground and style != 2 else "Corner_Exterior_Wood"
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var basis := Basis(Vector3.UP, atan2(float(cx), float(cz)) - PI * 0.25)
				_place(corner, Transform3D(basis, Vector3(cx * hw, y, cz * hd)))
		# Floor between storeys (seen through upper windows).
		if level > 0:
			for ix in width_cells:
				for iz in depth_cells:
					_place("Floor_WoodDark", Transform3D(Basis(), Vector3(-hw + CELL * (ix + 0.5), y, -hd + CELL * (iz + 0.5))))
	# Roof: ridge along Z, gables front and back.
	var top := floors * STOREY
	var roof := _roof_piece(width_cells * 2, depth_cells * 2)
	_place(roof, Transform3D(Basis(), Vector3(0, top, 0)))
	var gable := "Roof_Front_Brick%d" % (width_cells * 2)
	if not ResourceLoader.exists(VillageKit.KIT + gable + ".fbx"):
		gable = "Roof_Front_Brick%d" % clampi(width_cells * 2, 4, 8)
	_place(gable, Transform3D(Basis(), Vector3(0, top, hd)))
	_place(gable, Transform3D(Basis(Vector3.UP, PI), Vector3(0, top, -hd)))
	chimney_top = null
	if chimney:
		# Through the roof slope, standing ~1.4 m proud of the tiles.
		var ridge := {4: 3.7, 6: 4.9, 8: 6.0}.get(_roof_width(width_cells * 2), 4.9) as float
		var roof_half := {4: 2.75, 6: 4.12, 8: 4.98}.get(_roof_width(width_cells * 2), 4.12) as float
		var cx := hw * 0.35 * (1.0 if rng.randf() < 0.5 else -1.0)
		var surface := top + ridge * (1.0 - absf(cx) / roof_half)
		var base_y := surface - 1.8
		_place("Prop_Chimney", Transform3D(Basis(), Vector3(cx, base_y, -hd * 0.3)))
		chimney_top = Vector3(cx, base_y + 3.2, -hd * 0.3)


func _family(ground: bool) -> String:
	match style:
		0:
			return "Wall_Plaster"
		1:
			return "Wall_UnevenBrick" if ground else "Wall_Plaster"
	return "Wall_Plaster"


## Wall pieces span x∈[-1,1] with their outside toward +Z.
func _edge_transform(side: int, along: float, y: float, hw: float, hd: float) -> Transform3D:
	match side:
		0: return Transform3D(Basis(), Vector3(along, y, hd))
		1: return Transform3D(Basis(Vector3.UP, PI), Vector3(-along, y, -hd))
		2: return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hw, y, -along))
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hw, y, along))


func _roof_width(w: int) -> int:
	var best_w := 4
	for cand in [4, 6, 8]:
		if cand <= w:
			best_w = cand
	return best_w


func _roof_piece(w: int, d: int) -> String:
	var best_w := _roof_width(w)
	for dd in range(d, 1, -2):
		var n := "Roof_RoundTiles_%dx%d" % [best_w, dd]
		if ResourceLoader.exists(VillageKit.KIT + n + ".fbx"):
			return n
	return "Roof_RoundTiles_4x4"


func _place(piece_name: String, xf: Transform3D) -> Node3D:
	if not ResourceLoader.exists(VillageKit.KIT + piece_name + ".fbx"):
		push_warning("KitHouse: no piece %s" % piece_name)
		return null
	var n := VillageKit.piece(piece_name)
	n.transform = xf
	n.set_meta(&"kit", true)
	# Roof colour varies house to house (seed and plot), not by building type.
	var plot := roundi(global_position.x / 4.0) + roundi(global_position.z / 4.0) if is_inside_tree() else 0
	if posmod(random_seed + plot, 2) == 0:
		_redden_roof(n)
	add_child(n)
	return n


## Swaps the brown roof tiles for faded red clay (every other house).
func _redden_roof(n: Node) -> void:
	var brown := VillageKit.material("MI_RoundTiles")
	var red := VillageKit.material("MI_RoundTiles_Red")
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(i) == brown:
				mi.set_surface_override_material(i, red)


## A barrel, planter or bench beside the door, and a lantern above it.
func _dress_door(xf: Transform3D, rng: RandomNumberGenerator) -> void:
	for side: float in [-1.0, 1.0]:
		if rng.randf() < 0.35:
			continue
		var at := xf * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), Vector3(side * rng.randf_range(1.2, 1.7), 0, 0.55))
		var roll := rng.randf()
		var n: Node3D
		if roll < 0.4:
			n = PHModels.node("planter_box_01")
		elif roll < 0.75:
			var b := PropModel.new()
			b.kind = PropModel.Kind.BARREL
			n = b
		else:
			var c := PropModel.new()
			c.kind = PropModel.Kind.CRATE
			n = c
		n.transform = at
		n.set_meta(&"kit", true)
		add_child(n)
	if rng.randf() < 0.6:
		var lamp := PHModels.node("wooden_lantern_01")
		lamp.transform = xf * Transform3D(Basis(), Vector3(0.9, 2.35, 0.2))
		lamp.set_meta(&"kit", true)
		add_child(lamp)
