shader_type spatial;
// Additive white overlay used as a brief "you hit it" flash.
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float strength = 0.65;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = flash_color.rgb * strength * (0.6 + rim);
}
