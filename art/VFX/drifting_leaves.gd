class_name DriftingLeaves
extends GPUParticles3D
## A few leaves drifting down through the air around the camera's focus, as
## in the riverside reference: lazy fall, gentle sway and spin. Follows its
## target (the player) so they are always in view.

@export var target: Node3D
## Leaves only drift outdoors (the sun is off inside the crypt).
@export var sun: Node3D
@export var area := Vector3(26, 10, 22)

static var _leaf_tex: ImageTexture


func _ready() -> void:
	amount = 36
	lifetime = 9.0
	preprocess = 9.0
	visibility_aabb = AABB(-area * 0.5 - Vector3(0, 5, 0), area + Vector3(0, 10, 0))
	local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = area * 0.5
	pm.direction = Vector3(0.4, -1, 0.2)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.25, -0.35, 0.1)
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.72, 0.3, 0.0))
	ramp.add_point(0.1, Color(0.55, 0.72, 0.3, 1.0))
	ramp.add_point(0.85, Color(0.62, 0.7, 0.28, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.62, 0.3, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.09)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _leaf()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	draw_pass_1 = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var outdoors := sun == null or sun.visible
	if emitting != outdoors:
		emitting = outdoors
	visible = outdoors
	if target:
		global_position = target.global_position + Vector3(0, area.y * 0.5, 0)


static func _leaf() -> ImageTexture:
	if _leaf_tex:
		return _leaf_tex
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		for x in 32:
			var u := (x - 15.5) / 15.5
			var v := (y - 9.5) / 9.5
			# Pointed ellipse with a central vein.
			var inside := u * u + (v * v) / maxf(1.0 - absf(u) * 0.55, 0.05) < 1.0
			var c := Color(1, 1, 1, 1.0 if inside else 0.0)
			if inside and absf(v) < 0.08:
				c = Color(0.8, 0.85, 0.7, 1)
			img.set_pixel(x, y, c)
	_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex
