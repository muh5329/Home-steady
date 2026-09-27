class_name Gulls
extends Node3D
## A few gulls wheeling over the water, as over the harbour in the
## references: each glides a lazy loop at its own height and speed, flaps
## now and then, and banks into the turn. Pure decoration.

@export var count := 6
@export var radius := Vector2(5.0, 11.0)
@export var height := Vector2(8.0, 12.0)

var _birds: Array[Node3D] = []
var _state: Array = []  # [angle, speed, radius, height, phase, centre offset]
var _t := 0.0

static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = _build()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in count:
		var bird := Node3D.new()
		add_child(bird)
		for side: float in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.mesh = _mesh
			wing.scale = Vector3(side, 1, 1)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bird.add_child(wing)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.06
		capsule.height = 0.42
		capsule.radial_segments = 6
		capsule.rings = 2
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.92, 0.9)
		capsule.material = m
		body.mesh = capsule
		body.rotation.x = PI * 0.5
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bird.add_child(body)
		_birds.append(bird)
		_state.append([rng.randf() * TAU, rng.randf_range(0.18, 0.3) * (1.0 if rng.randf() < 0.6 else -1.0),
			rng.randf_range(radius.x, radius.y), rng.randf_range(height.x, height.y), rng.randf() * 10.0,
			Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))])


func _process(delta: float) -> void:
	_t += delta
	for i in _birds.size():
		var s: Array = _state[i]
		s[0] += s[1] * delta
		var a: float = s[0]
		var r: float = s[2]
		var h: float = s[3] + sin(_t * 0.3 + s[4]) * 0.8
		var pos: Vector3 = s[5] + Vector3(cos(a) * r, h, sin(a) * r)
		var bird := _birds[i]
		bird.position = pos
		var dir := Vector3(-sin(a), 0, cos(a)) * signf(s[1])
		bird.basis = Basis.looking_at(dir, Vector3.UP).rotated(dir.normalized(), -signf(s[1]) * 0.35)
		# Flap in bursts, glide in between.
		var burst := smoothstep(0.55, 0.8, sin(_t * 0.5 + s[4]) * 0.5 + 0.5)
		var flap := sin(_t * 11.0 + s[4]) * 0.55 * burst + 0.12
		bird.get_child(0).rotation.z = flap
		bird.get_child(1).rotation.z = -flap


## One wing: a swept, tapering blade with a grey tip, reaching out along +X.
static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.94, 0.94, 0.92)
	var grey := Color(0.35, 0.37, 0.4)
	var pts := [Vector3(0.03, 0, 0.1), Vector3(0.03, 0, -0.1), Vector3(0.38, 0.03, -0.06), Vector3(0.36, 0.03, 0.12), Vector3(0.62, 0.0, -0.14), Vector3(0.56, 0.0, 0.02)]
	var quads := [[0, 1, 2, 3, white], [3, 2, 4, 5, grey]]
	for q in quads:
		st.set_color(q[4])
		for idx in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[idx])
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	mesh.surface_set_material(0, m)
	return mesh
