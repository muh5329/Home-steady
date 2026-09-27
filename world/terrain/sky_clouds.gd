class_name SkyClouds
extends Node3D
## A few big soft storybook clouds drifting slowly around the horizon.

@export var count := 24
@export var radius := Vector2(110.0, 240.0)
@export var height := Vector2(32.0, 64.0)
@export var scale_range := Vector2(18.0, 34.0)
@export var drift_speed := 0.6
@export var random_seed := 21

const MESHES := ["res://art/third_party/kaykit/medieval/decoration/nature/cloud_big.gltf",
	"res://art/third_party/kaykit/medieval/decoration/nature/cloud_small.gltf"]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.98, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.6, 0.72)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 1.0
	for i in count:
		var cloud: Node3D = load(MESHES[i % MESHES.size()]).instantiate()
		for m in cloud.find_children("*", "MeshInstance3D", true, false):
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius.x, radius.y)
		cloud.position = Vector3(cos(a) * r, rng.randf_range(height.x, height.y), sin(a) * r)
		cloud.rotation.y = rng.randf() * TAU
		cloud.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		add_child(cloud)


func _process(delta: float) -> void:
	rotation.y += deg_to_rad(drift_speed) * delta * 0.1
