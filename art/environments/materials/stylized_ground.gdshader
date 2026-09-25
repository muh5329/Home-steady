shader_type spatial;
// Stylized painterly ground: large-scale colour variation between lush and
// dry grass, darker patches, and subtle small-scale breakup. World-space so
// any mesh can use it without UVs.

uniform vec3 grass_a : source_color = vec3(0.34, 0.55, 0.20);
uniform vec3 grass_b : source_color = vec3(0.50, 0.62, 0.24);
uniform vec3 grass_dark : source_color = vec3(0.22, 0.40, 0.16);
uniform vec3 dirt : source_color = vec3(0.52, 0.42, 0.28);
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.12;
uniform sampler2D noise_large : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_small : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n1 = texture(noise_large, p * 0.012).r;
	float n2 = texture(noise_large, p * 0.045 + vec2(0.31, 0.7)).r;
	float n3 = texture(noise_small, p * 0.35).r;
	vec3 col = mix(grass_a, grass_b, smoothstep(0.35, 0.65, n1));
	col = mix(col, grass_dark, smoothstep(0.55, 0.8, n2) * 0.55);
	float d = smoothstep(1.0 - dirt_amount, 1.0 - dirt_amount + 0.08, n2 * 0.6 + n1 * 0.4);
	col = mix(col, dirt, d * 0.85);
	col *= 0.9 + n3 * 0.2;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
