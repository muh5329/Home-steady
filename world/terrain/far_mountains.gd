class_name FarMountains
extends MeshInstance3D
## A ring of distant blue mountains on the horizon: one unlit strip with a
## noisy ridge line, tinted like air so it reads as far away.

@export var radius := 330.0
@export var height := Vector2(22.0, 75.0)
@export var segments := 160
@export var top_color := Color(0.46, 0.58, 0.74)
@export var foot_color := Color(0.64, 0.73, 0.84)
@export var random_seed := 5


func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 2.2
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge: Array[Vector3] = []
	for i in segments + 1:
		var a := TAU * i / segments
		var dir := Vector2(cos(a), sin(a))
		var n := noise.get_noise_2d(dir.x, dir.y) * 0.5 + 0.5
		var h := lerpf(height.x, height.y, clampf(n * n * 1.4, 0.0, 1.0))
		ridge.append(Vector3(dir.x * radius, h, dir.y * radius))
	for i in segments:
		var t0 := ridge[i]
		var t1 := ridge[i + 1]
		var b0 := Vector3(t0.x, -8.0, t0.z)
		var b1 := Vector3(t1.x, -8.0, t1.z)
		for v in [[b0, foot_color], [t1, top_color], [t0, top_color], [b0, foot_color], [b1, foot_color], [t1, top_color]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
