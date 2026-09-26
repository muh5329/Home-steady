shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// Painterly grass blades: colour taken from the same world-space noise as
// the ground (so tufts melt into it), darker roots, sunlit tips, a soft
// backlight glow and a gentle wind sway that grows toward the tip.
// COLOR.a = height along the blade (0 root, 1 tip).

uniform vec3 grass_lush : source_color = vec3(0.38, 0.54, 0.16);
uniform vec3 grass_deep : source_color = vec3(0.23, 0.39, 0.12);
uniform vec3 grass_warm : source_color = vec3(0.60, 0.58, 0.22);
uniform vec3 tip_color : source_color = vec3(0.56, 0.64, 0.24);
uniform sampler2D noise_large : repeat_enable, filter_linear_mipmap;
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.3;

varying vec3 world_pos;
varying float tip;

void vertex() {
	tip = COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = texture(noise_large, wp.xz * 0.02 + vec2(TIME * 0.03 * wind_speed, 0.0)).r;
	float sway = sin(TIME * wind_speed * 2.0 + wp.x * 0.35 + wp.z * 0.2) * 0.5 + gust;
	VERTEX.x += sway * wind_strength * tip * tip;
	VERTEX.z += sway * wind_strength * 0.5 * tip * tip;
	world_pos = wp;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Light every blade like the ground it grows from (world up), on both sides.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float n1 = texture(noise_large, world_pos.xz * 0.010).r;
	float n2 = texture(noise_large, world_pos.xz * 0.037 + vec2(0.31, 0.7)).r;
	vec3 base = mix(grass_deep, grass_lush, smoothstep(0.30, 0.62, n1));
	base = mix(base, grass_warm, smoothstep(0.58, 0.82, n2) * 0.6);
	vec3 col = mix(base * 0.92, mix(base, tip_color, 0.22), smoothstep(0.0, 1.0, tip));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35, 0.45, 0.12) * tip;
	AO = mix(0.8, 1.0, tip);
}
