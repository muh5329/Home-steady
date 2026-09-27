class_name Minimap
extends Control
## Round minimap in an ornate dark-iron ring (top right, like the
## references): a map drawn from the ground's own paint mask (roads,
## cobbles, fields, beaches) and the river, buildings as blocks, settlers
## as dots, the crypt as a marker and the player as an arrow in the
## middle. North stays up; the view follows the player.

const SHADER := preload("res://ui/hud/minimap.gdshader")

@export var radius := 118.0
## World metres from the centre to the rim.
@export var world_radius := 55.0

var player: Node3D
var _map: TextureRect
var _mat: ShaderMaterial
var _bound := false


func _ready() -> void:
	custom_minimum_size = Vector2(radius, radius) * 2.0 + Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = TextureRect.new()
	_map.position = Vector2(12, 12)
	_map.size = Vector2(radius, radius) * 2.0
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	_map.texture = ImageTexture.create_from_image(blank)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_map.material = _mat
	add_child(_map)


func _process(_delta: float) -> void:
	if not _bound:
		_bind()
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Player.GROUP) as Node3D
		return
	_mat.set_shader_parameter(&"centre", Vector2(player.global_position.x, player.global_position.z))
	_mat.set_shader_parameter(&"world_radius", world_radius)
	queue_redraw()


func _bind() -> void:
	var painter := TerrainPainter.of(self)
	if painter == null or painter.ground == null:
		return
	var gm := painter.ground.material_override as ShaderMaterial
	if gm == null and painter.ground is MeshInstance3D:
		gm = (painter.ground as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	if gm == null:
		return
	_mat.set_shader_parameter(&"paint_mask", gm.get_shader_parameter(&"paint_mask"))
	_mat.set_shader_parameter(&"mask_rect", gm.get_shader_parameter(&"mask_rect"))
	_mat.set_shader_parameter(&"water_mask", gm.get_shader_parameter(&"water_mask"))
	_mat.set_shader_parameter(&"water_rect", gm.get_shader_parameter(&"water_rect"))
	_bound = gm.get_shader_parameter(&"paint_mask") != null


func _to_map(world: Vector3) -> Vector2:
	var c := Vector2(player.global_position.x, player.global_position.z)
	var d := (Vector2(world.x, world.z) - c) / world_radius * radius
	return Vector2(12, 12) + Vector2(radius, radius) + d


func _inside(p: Vector2, margin := 6.0) -> bool:
	return p.distance_to(Vector2(12, 12) + Vector2(radius, radius)) < radius - margin


func _draw() -> void:
	var centre := Vector2(12, 12) + Vector2(radius, radius)
	if player and is_instance_valid(player):
		# Buildings and sites.
		for reg in get_tree().get_nodes_in_group(BuildingRegistry.GROUP):
			for b in reg.get_children():
				if not (b is Node3D):
					continue
				var p := _to_map(b.global_position)
				if _inside(p, 10):
					var s := 5.5
					draw_set_transform(p, -b.global_rotation.y, Vector2.ONE)
					draw_rect(Rect2(-s, -s, s * 2, s * 2), Color(0.32, 0.3, 0.29))
					draw_rect(Rect2(-s, -s, s * 2, s * 2), Color(0.1, 0.09, 0.08), false, 1.5)
					draw_set_transform(Vector2.ZERO)
		# Settlers and monsters.
		for s in get_tree().get_nodes_in_group(Settler.GROUP):
			var p := _to_map((s as Node3D).global_position)
			if _inside(p):
				draw_circle(p, 3.2, Color(0.2, 0.12, 0.05))
				draw_circle(p, 2.4, Color(1.0, 0.85, 0.35))
		var me := (player as Player).combat if player is Player else null
		for node in get_tree().get_nodes_in_group(CombatController.GROUP):
			var c := node as CombatController
			if me == null or c == me or not c.is_alive() or not me.is_hostile_to(c):
				continue
			var body := c.body as Node3D
			if body and body.is_visible_in_tree():
				var p := _to_map(body.global_position)
				if _inside(p):
					draw_circle(p, 3.2, Color(0.25, 0.02, 0.02))
					draw_circle(p, 2.4, Color(0.95, 0.25, 0.2))
		# Player arrow (points where the camera looks).
		var yaw := 0.0
		var cam := get_viewport().get_camera_3d()
		if cam:
			var f := -cam.global_basis.z
			yaw = atan2(f.x, -f.z)
		var tri := PackedVector2Array([Vector2(0, -9), Vector2(6.5, 7), Vector2(0, 3.5), Vector2(-6.5, 7)])
		var xf := Transform2D(yaw, centre)
		var pts := PackedVector2Array()
		for v in tri:
			pts.append(xf * v)
		draw_colored_polygon(pts, Color(1.0, 0.8, 0.3))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.2, 0.1, 0.02), 1.5)
	# Ornate ring: dark iron band, bevel highlights, rivets and a north mark.
	draw_arc(centre, radius + 5, 0, TAU, 96, Color(0.09, 0.08, 0.08), 12.0, true)
	draw_arc(centre, radius + 10.5, 0, TAU, 96, Color(0.55, 0.5, 0.44), 1.6, true)
	draw_arc(centre, radius - 0.5, 0, TAU, 96, Color(0.45, 0.4, 0.34), 1.6, true)
	for i in 24:
		var a := TAU * i / 24.0
		var p := centre + Vector2(cos(a), sin(a)) * (radius + 5)
		draw_circle(p, 2.2 if i % 3 == 0 else 1.3, Color(0.62, 0.56, 0.48))
	var n := centre + Vector2(0, -radius - 7)
	draw_colored_polygon(PackedVector2Array([n + Vector2(0, -9), n + Vector2(7, 3), n + Vector2(-7, 3)]), Color(0.75, 0.66, 0.5))
