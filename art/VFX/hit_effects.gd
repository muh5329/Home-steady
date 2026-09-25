class_name HitEffects
extends Node3D
## Spawns pooled impact particles wherever damage lands (listens to
## EventBus.damage_applied). One per region; nothing calls it directly.

const POOL_SIZE := 12

var _pool: Array[GPUParticles3D] = []
var _next := 0
var _spark_material: ParticleProcessMaterial
var _dust_material: ParticleProcessMaterial


func _ready() -> void:
	_spark_material = _make_process(Color(1.0, 0.85, 0.5), 5.5, 0.35)
	_dust_material = _make_process(Color(0.9, 0.88, 0.8), 2.5, 0.6)
	for i in POOL_SIZE:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 14
		p.lifetime = 0.45
		p.explosiveness = 0.95
		p.local_coords = false
		p.draw_pass_1 = _make_mesh()
		add_child(p)
		_pool.append(p)
	EventBus.damage_applied.connect(_on_damage_applied)


func _on_damage_applied(event: DamageEvent) -> void:
	var blocked := event.has_tag("blocked")
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.process_material = _spark_material if blocked or event.has_tag("heavy") else _dust_material
	p.amount = 22 if event.has_tag("heavy") else 12
	p.global_position = event.hit_position
	p.restart()
	p.emitting = true


func _make_process(color: Color, speed: float, scale_max: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 75.0
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -12, 0)
	m.scale_min = scale_max * 0.4
	m.scale_max = scale_max
	m.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var tex := CurveTexture.new()
	tex.curve = curve
	m.scale_curve = tex
	return m


func _make_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.4, 1.3, 1.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	mat.albedo_texture = dot
	mesh.material = mat
	return mesh
