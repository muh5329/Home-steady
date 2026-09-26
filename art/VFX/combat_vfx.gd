class_name CombatVfx
## One-shot combat effects shared by projectiles and area attacks.


## Expanding ring + particle burst + light flash at `point`.
static func burst(parent: Node, point: Vector3, radius: float, color: Color) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = point

	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 64
	p.lifetime = 0.7
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = radius * 2.0
	m.initial_velocity_max = radius * 3.5
	m.gravity = Vector3(0, -2, 0)
	m.damping_min = 4.0
	m.damping_max = 6.0
	m.color = color
	m.scale_min = 0.35
	m.scale_max = 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = _additive(Color(1, 1, 1), true)
	p.draw_pass_1 = quad
	root.add_child(p)
	p.emitting = true

	# Flat expanding shock ring on the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _additive(color * 1.6, false)
	ring.scale = Vector3(0.2, 0.05, 0.2)
	ring.position.y = 0.15
	root.add_child(ring)
	var tween := root.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.45)

	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 9.0
	flash.omni_range = radius * 2.5
	flash.position.y = 0.6
	root.add_child(flash)
	tween.tween_property(flash, "light_energy", 0.0, 0.5)
	root.get_tree().create_timer(1.2, false).timeout.connect(root.queue_free)


## A danger circle on the ground that fills in until the hit lands.
static func telegraph(parent: Node, point: Vector3, radius: float, seconds: float, color: Color) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = point + Vector3.UP * 0.08
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	edge.mesh = torus
	edge.material_override = _additive(color * 1.4, false)
	edge.scale = Vector3(radius, 0.02, radius)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	var fill := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 32
	fill.mesh = disc
	fill.material_override = _additive(Color(color.r, color.g, color.b, 0.35), false)
	fill.scale = Vector3(0.05, 1.0, 0.05)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fill)
	var tween := root.create_tween()
	tween.tween_property(fill, "scale", Vector3(radius, 1.0, radius), maxf(seconds, 0.05))
	tween.tween_callback(root.queue_free)


static func _additive(color: Color, particles: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	if particles:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = soft_dot()
	return mat


static var _dot: GradientTexture2D

## Soft round sprite for particles (shared).
static func soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = g
	return _dot
