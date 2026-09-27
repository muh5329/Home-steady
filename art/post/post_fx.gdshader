shader_type canvas_item;
// Fabledom-style lens finish: soft vignette, slight chromatic fringe
// toward the edges, a warm lift in the highlights and a cool push in the
// shadows (split toning).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.38;
uniform float vignette_radius = 0.82;
uniform float fringe = 0.0;
uniform vec3 highlight_tint = vec3(1.04, 0.99, 0.9);
uniform vec3 shadow_tint = vec3(0.93, 0.97, 1.08);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.0, 0.8));
	vec2 off = c * fringe * smoothstep(0.2, 0.8, r) * 4.0;
	vec3 col;
	col.r = texture(screen, uv + off).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - off).b;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(shadow_tint, highlight_tint, smoothstep(0.15, 0.75, luma));
	float v = smoothstep(vignette_radius, 0.25, r);
	col *= mix(1.0 - vignette_strength, 1.0, v);
	COLOR = vec4(col, 1.0);
}
