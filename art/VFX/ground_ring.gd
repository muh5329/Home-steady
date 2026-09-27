class_name GroundRing
extends MeshInstance3D
## A soft pale ring on the ground under the hero, as in the references, so
## the player is easy to find in a busy isometric frame.

@export var radius := 0.75
@export var color := Color(1.0, 0.97, 0.9, 0.32)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.62, 0.8, r) * (1.0 - smoothstep(0.86, 1.0, r));
	float fill = (1.0 - smoothstep(0.0, 0.8, r)) * 0.18;
	ALBEDO = tint.rgb;
	ALPHA = (ring + fill) * tint.a;
}
"""


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * radius * 2.0
	q.orientation = PlaneMesh.FACE_Y
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"tint", color)
	q.material = m
	mesh = q
	position.y = 0.04
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
