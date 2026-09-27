class_name WorldMap
extends CanvasLayer
## The illustrated world map (M): a bright storybook overworld in the
## style of Cat Quest, drawn from the live world. Terrain, roads, beaches
## and the river come from the ground's masks; hills, forests, buildings,
## the camp, the crypt and the hamlet are drawn as little icons with
## hand-lettered labels; clouds drift over the edges. Wheel zooms.

const SHADER := preload("res://ui/map/world_map.gdshader")
const TILT := preload("res://ui/map/map_tilt.gdshader")
const OPEN_ACTION_KEY := KEY_M

var _root: Control
## The map is drawn flat into a SubViewport, then shown tilted away from
## the viewer (a storybook overworld seen at an angle).
var _vp: SubViewport
var _screen: TextureRect
var _overlay: Control
var _ci: CanvasItem
var _map: TextureRect
var _mat: ShaderMaterial
var _icons: Control
var _zoom := 1.0
var _time := 0.0
var _font: Font
var _forest: PackedVector3Array = []  # x, z, size


func _ready() -> void:
	layer = 20
	visible = false
	_font = load("res://art/fonts/Cinzel-Bold.woff2")
	_vp = SubViewport.new()
	_vp.size = Vector2i(1600, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_root = Control.new()
	_root.size = Vector2(1600, 900)
	_vp.add_child(_root)
	_screen = TextureRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture = _vp.get_texture()
	var tilt := ShaderMaterial.new()
	tilt.shader = TILT
	_screen.material = tilt
	add_child(_screen)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.08, 0.08, 0.92)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(back)
	_map = TextureRect.new()
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	_map.texture = ImageTexture.create_from_image(blank)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	_mat.set_shader_parameter(&"noise", nt)
	_map.material = _mat
	_root.add_child(_map)
	_icons = Control.new()
	_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_icons)
	_root.add_child(_icons)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == OPEN_ACTION_KEY:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.15, 1.0, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.15, 1.0, 3.0)
	elif visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_bind()
		_layout()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_layout()
	_icons.queue_redraw()
	_overlay.queue_redraw()


## World rect on screen: a square fitted to the window, centred on the
## player when zoomed in.
func _view_rect() -> Rect2:
	var size := 330.0 / _zoom
	var centre := Vector2.ZERO
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	if player and _zoom > 1.0:
		centre = Vector2(player.global_position.x, player.global_position.z)
		centre = centre.clamp(Vector2(-150 + size * 0.5, -150 + size * 0.5), Vector2(150 - size * 0.5, 150 - size * 0.5))
	return Rect2(centre - Vector2(size, size) * 0.5, Vector2(size, size))


func _layout() -> void:
	# Full screen: the island fills the view with sea round its edges.
	var vp := get_viewport().get_visible_rect().size
	if Vector2i(vp) != _vp.size:
		_vp.size = Vector2i(vp)
	_root.size = vp
	var box := vp
	_map.position = Vector2.ZERO
	_map.size = box
	var view := _view_rect()
	# Wider than tall: show more world east-west.
	var aspect := box.x / box.y
	view = Rect2(view.position.x - view.size.x * (aspect - 1.0) * 0.5, view.position.y, view.size.x * aspect, view.size.y)
	_mat.set_shader_parameter(&"view_rect", Vector4(view.position.x, view.position.y, view.size.x, view.size.y))
	_map.set_meta(&"view", view)


func _bind() -> void:
	var painter := TerrainPainter.of(self)
	if painter and painter.ground:
		var gm := painter.ground.material_override as ShaderMaterial
		if gm == null and painter.ground is MeshInstance3D:
			gm = (painter.ground as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		if gm:
			for p in [&"paint_mask", &"mask_rect", &"water_mask", &"water_rect"]:
				_mat.set_shader_parameter(p, gm.get_shader_parameter(p))
	if _forest.is_empty():
		_plant_forest()


## Forest clumps: the tree belt round the edge of the land and the woods
## beyond, kept off roads, water and beaches.
func _plant_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var painter := TerrainPainter.of(self)
	# Woods grow in clumps: a centre, then a tight scatter of trees round it.
	for c in 150:
		var centre := Vector2(rng.randf_range(-150, 150), rng.randf_range(-145, 145))
		var inner := absf(centre.x) < 58.0 and absf(centre.y) < 58.0
		if inner and rng.randf() < 0.85:
			continue
		var count := rng.randi_range(4, 14)
		var spread := rng.randf_range(5.0, 11.0)
		for i in count:
			var p := centre + Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)) * spread
			if (p / Vector2(150, 140)).length() > 0.74:
				continue  # the sea
			var pos := Vector3(p.x, 0, p.y)
			if River.covered(self, pos, 4.0) or (painter and painter.coverage(pos) > 0.05):
				continue
			if ((p - Vector2(-82, -58)) / Vector2(21, 15)).length() < 1.0 or ((p - Vector2(78, 72)) / Vector2(17, 13)).length() < 1.0:
				continue  # the lakes
			if p.y > 60.0 and absf(p.x) < 14.0:
				continue
			_forest.append(Vector3(p.x, p.y, rng.randf_range(3.0, 4.6)))
	# Draw back to front so lower trees overlap the ones behind.
	var arr := Array(_forest)
	arr.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	_forest = PackedVector3Array(arr)


func _to_screen(world: Vector3) -> Vector2:
	var view: Rect2 = _map.get_meta(&"view", Rect2(-130, -130, 260, 260))
	var uv := (Vector2(world.x, world.z) - view.position) / view.size
	return _map.position + uv * _map.size


func _scale() -> float:
	var view: Rect2 = _map.get_meta(&"view", Rect2(-130, -130, 260, 260))
	return _map.size.x / view.size.x


func _draw_icons() -> void:
	_ci = _icons
	if _map.size.x < 50.0:
		return
	var k := _scale()
	var clip := Rect2(_map.position, _map.size)
	# Hills: green mountains with a shaded face.
	for hills in get_tree().get_nodes_in_group(TerraceHills.GROUP):
		for h: Vector4 in hills.hills:
			if (Vector2(h.x, h.y) / Vector2(152, 142)).length() > 0.8:
				continue  # would stand in the sea
			var p := _to_screen(Vector3(h.x, 0, h.y))
			if clip.grow(-10).has_point(p):
				_mountain(p, minf(h.z * k * 0.6, 70.0))
	# Forests: shadows first, then the trees.
	for f in _forest:
		var p := _to_screen(Vector3(f.x, 0, f.y))
		if clip.grow(-6).has_point(p):
			_tree_shadow(p, f.z * k * 0.5)
	for f in _forest:
		var p := _to_screen(Vector3(f.x, 0, f.y))
		if clip.grow(-6).has_point(p):
			_tree(p, f.z * k * 0.5)
	# Settlement buildings and the hamlet.
	for reg in get_tree().get_nodes_in_group(BuildingRegistry.GROUP):
		for b in reg.get_children():
			if b is Node3D:
				_house(_to_screen(b.global_position), k * 2.2)
	for kit in get_tree().get_nodes_in_group(CameraOcclusion.GROUP):
		if kit is KitHouse and not (kit.get_parent().get_parent() is BuildingRegistry):
			var p := _to_screen((kit as Node3D).global_position)
			if clip.has_point(p) and not (kit.get_parent() is Building):
				_house(p, k * 2.2)
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var camp := root.find_child("Camp", true, false) as Node3D
	if camp:
		var p := _to_screen(camp.global_position)
		_tent(p, k * 2.4)
		_banner(p + Vector2(0, 30), "The Camp", 15)
	var crypt := root.find_child("CryptEntrance", true, false) as Node3D
	if crypt:
		var p := _to_screen(crypt.global_position)
		_crypt(p, k * 2.6)
		_banner(p + Vector2(0, 34), "Old Crypt", 15)
	var hamlet := root.find_child("Hamlet", true, false) as Node3D
	if hamlet:
		_banner(_to_screen(Vector3(60, 0, -4)) + Vector2(0, 34), "Riverside", 15)
	_label(_to_screen(Vector3(31, 0, -60)), "Greenwater", 14, Color(0.9, 1.0, 1.0))
	_label(_to_screen(Vector3(-82, 0, -56)), "Mirror Mere", 13, Color(0.9, 1.0, 1.0))
	_label(_to_screen(Vector3(78, 0, 74)), "Reed Pool", 13, Color(0.9, 1.0, 1.0))
	# The player: a golden pin with a pulse.
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	if player:
		var p := _to_screen(player.global_position)
		var pulse := fmod(_time, 1.4) / 1.4
		_ci.draw_arc(p, 8 + pulse * 22, 0, TAU, 32, Color(1, 0.9, 0.4, 1.0 - pulse), 2.5, true)
		_ci.draw_circle(p + Vector2(0, -16), 10, Color(0.35, 0.2, 0.05))
		_ci.draw_circle(p + Vector2(0, -16), 8, Color(1.0, 0.8, 0.25))
		_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -12), p + Vector2(7, -12), p]), Color(1.0, 0.8, 0.25))
		_ci.draw_circle(p + Vector2(0, -16), 3.5, Color(0.35, 0.2, 0.05))
	# Clouds drifting across.
	for i in 5:
		var cx := fmod(_time * 6.0 + i * 181.0, _map.size.x + 200.0) - 100.0
		var cy := fmod(i * 97.0 + 40.0, _map.size.y - 60.0) + 30.0
		_cloud(_map.position + Vector2(cx, cy), 26.0 + (i % 3) * 8.0)


## Title, hint and zoom badge stay flat on top of the tilted map.
func _draw_overlay() -> void:
	_ci = _overlay
	var clip := Rect2(Vector2.ZERO, _overlay.size)
	var badge := clip.end - Vector2(70, 70)
	_ci.draw_circle(badge, 26, Color(0.45, 0.3, 0.16))
	_ci.draw_arc(badge, 26, 0, TAU, 32, Color(0.95, 0.85, 0.6), 3.0, true)
	_ci.draw_arc(badge + Vector2(-4, -4), 10, 0, TAU, 24, Color(0.98, 0.95, 0.85), 3.5, true)
	_ci.draw_line(badge + Vector2(3, 3), badge + Vector2(12, 12), Color(0.98, 0.95, 0.85), 4.0)
	_banner(Vector2(clip.get_center().x, clip.position.y + 48), "The Valley of Home Steady", 28)
	_label(Vector2(clip.get_center().x, clip.end.y - 24), "[M] close   ·   wheel to zoom", 14, Color(1, 1, 1, 0.85))


## A place name on a little parchment ribbon with swallow-tailed ends.
func _banner(at: Vector2, text: String, fs: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := fs * 1.5
	var r := Rect2(at - Vector2(w * 0.5 + fs * 0.8, h * 0.72), Vector2(w + fs * 1.6, h))
	var ink := Color(0.25, 0.14, 0.06)
	var paper := Color(0.97, 0.9, 0.72)
	for side: float in [-1.0, 1.0]:
		var x0 := r.position.x if side < 0.0 else r.end.x
		var tail := PackedVector2Array([Vector2(x0, r.position.y + h * 0.2), Vector2(x0 + side * fs * 0.9, r.position.y + h * 0.2), Vector2(x0 + side * fs * 0.5, r.position.y + h * 0.6), Vector2(x0 + side * fs * 0.9, r.end.y + h * 0.15), Vector2(x0, r.end.y + h * 0.15)])
		_ci.draw_colored_polygon(tail, paper.darkened(0.18))
		tail.append(tail[0])
		_ci.draw_polyline(tail, ink, 1.5)
	_ci.draw_rect(r, paper)
	_ci.draw_rect(r, ink, false, 2.0)
	_ci.draw_string(_font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _label(at: Vector2, text: String, fs: int, col := Color.WHITE) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_ci.draw_string_outline(_font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.1, 0.12, 0.08, 0.9))
	_ci.draw_string(_font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _tree_shadow(p: Vector2, r: float) -> void:
	r = maxf(r, 3.0)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(p + Vector2(r * 0.7, r * 0.75) + Vector2(cos(a) * r * 1.2, sin(a) * r * 0.55))
	_ci.draw_colored_polygon(pts, Color(0.05, 0.2, 0.05, 0.35))


func _tree(p: Vector2, r: float) -> void:
	r = maxf(r, 3.0)
	# A round storybook tree: dark rim, deep green crown, a sunlit cap.
	var h := absf(sin(p.x * 12.9898 + p.y * 78.233))
	var crown := Color(0.1, 0.34, 0.13).lerp(Color(0.2, 0.42, 0.12), h)
	_ci.draw_circle(p + Vector2(0, r * 0.1), r * 1.08, Color(0.04, 0.16, 0.06))
	_ci.draw_circle(p, r, crown)
	_ci.draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.55, crown.lightened(0.22))
	_ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.42), r * 0.22, crown.lightened(0.45))


func _mountain(p: Vector2, r: float) -> void:
	r = maxf(r, 10.0)
	var peak := p + Vector2(0, -r * 1.1)
	var left := p + Vector2(-r, r * 0.35)
	var right := p + Vector2(r, r * 0.35)
	_ci.draw_colored_polygon(PackedVector2Array([left, peak, p + Vector2(r * 0.1, r * 0.35)]), Color(0.46, 0.74, 0.34))
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.1, r * 0.35), peak, right]), Color(0.28, 0.56, 0.26))
	_ci.draw_polyline(PackedVector2Array([left, peak, right]), Color(0.12, 0.3, 0.14), 2.0)
	_ci.draw_colored_polygon(PackedVector2Array([peak, peak + Vector2(-r * 0.22, r * 0.25), peak + Vector2(r * 0.22, r * 0.25)]), Color(0.9, 0.97, 0.9))


func _house(p: Vector2, s: float) -> void:
	s = clampf(s, 5.0, 16.0)
	var body := Rect2(p + Vector2(-s, -s * 0.6), Vector2(s * 2.0, s * 1.4))
	_ci.draw_rect(body, Color(0.95, 0.88, 0.72))
	_ci.draw_rect(body, Color(0.25, 0.15, 0.08), false, 1.5)
	var roof := PackedVector2Array([p + Vector2(-s * 1.25, -s * 0.55), p + Vector2(0, -s * 1.6), p + Vector2(s * 1.25, -s * 0.55)])
	_ci.draw_colored_polygon(roof, Color(0.8, 0.3, 0.15))
	roof.append(roof[0])
	_ci.draw_polyline(roof, Color(0.3, 0.1, 0.05), 1.5)
	_ci.draw_rect(Rect2(p + Vector2(-s * 0.25, s * 0.2), Vector2(s * 0.5, s * 0.6)), Color(0.35, 0.2, 0.1))


func _tent(p: Vector2, s: float) -> void:
	s = clampf(s, 6.0, 16.0)
	var tri := PackedVector2Array([p + Vector2(-s, s * 0.6), p + Vector2(0, -s), p + Vector2(s, s * 0.6)])
	_ci.draw_colored_polygon(tri, Color(0.95, 0.92, 0.82))
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.35, s * 0.6), p + Vector2(0, -s), p + Vector2(s * 0.35, s * 0.6)]), Color(0.8, 0.3, 0.2))
	tri.append(tri[0])
	_ci.draw_polyline(tri, Color(0.3, 0.12, 0.06), 1.5)


func _crypt(p: Vector2, s: float) -> void:
	s = clampf(s, 8.0, 18.0)
	_ci.draw_rect(Rect2(p + Vector2(-s, -s), Vector2(s * 2, s * 1.6)), Color(0.55, 0.55, 0.58))
	_ci.draw_circle(p + Vector2(0, -s * 0.2), s * 0.55, Color(0.12, 0.1, 0.12))
	_ci.draw_rect(Rect2(p + Vector2(-s * 0.55, -s * 0.2), Vector2(s * 1.1, s * 0.8)), Color(0.12, 0.1, 0.12))
	_ci.draw_rect(Rect2(p + Vector2(-s, -s), Vector2(s * 2, s * 1.6)), Color(0.18, 0.16, 0.2), false, 2.0)
	_ci.draw_circle(p + Vector2(-s * 0.2, -s * 0.05), s * 0.12, Color(0.9, 0.4, 0.3))
	_ci.draw_circle(p + Vector2(s * 0.2, -s * 0.05), s * 0.12, Color(0.9, 0.4, 0.3))


func _cloud(p: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.62)
	_ci.draw_circle(p, r, col)
	_ci.draw_circle(p + Vector2(r * 0.9, r * 0.2), r * 0.75, col)
	_ci.draw_circle(p + Vector2(-r * 0.9, r * 0.25), r * 0.7, col)
	_ci.draw_circle(p + Vector2(r * 0.3, -r * 0.45), r * 0.7, col)
