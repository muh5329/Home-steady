shader_type spatial;
render_mode cull_disabled;
// Terraced red-clay cliff sides: horizontal strata in warm reds and
// ochres, darker toward the foot, with a ragged lip of grass hanging over
// the top edge (UV.y = 0 at the foot of a terrace, 1 at its top).

uniform vec3 clay_a : source_color = vec3(0.76, 0.4, 0.25);
uniform vec3 clay_b : source_color = vec3(0.87, 0.57, 0.36);
uniform vec3 clay_c : source_color = vec3(0.48, 0.27, 0.2);
uniform vec3 grass : source_color = vec3(0.34, 0.52, 0.16);
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float around = UV.x;
	// UV.x runs in metres around the hill: sample slowly so strata wobble in
	// broad waves instead of flame-like teeth.
	float n = texture(noise, vec2(around * 0.012, world_pos.y * 0.05)).r;
	float n2 = texture(noise, vec2(around * 0.05 + 0.37, 0.61)).r;
	// Isotropic mottling in world space (UV.x stretches along the long
	// perimeter and turned into flame-like streaks).
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec2 tangent = vec2(-wn.z, wn.x);
	tangent /= max(length(tangent), 1e-3);
	float h = dot(world_pos.xz, tangent);
	float fine = texture(noise, vec2(h * 0.045, world_pos.y * 0.07)).r;
	// Soft vertical rain-wash streaks, faint.
	float wash = texture(noise, vec2(h * 0.09, world_pos.y * 0.012)).r;
	// Strata: broad bands in height, wobbling around the hill.
	float band = sin((world_pos.y + n * 2.6) * 1.1) * 0.5 + 0.5;
	float band2 = sin((world_pos.y + n * 1.8 + fine * 0.8) * 2.6 + 1.3) * 0.5 + 0.5;
	vec3 col = mix(clay_a, clay_b, smoothstep(0.35, 0.8, band));
	col = mix(col, clay_c, smoothstep(0.7, 0.95, band2) * 0.6);
	col *= 0.88 + fine * 0.18;
	col *= 0.94 + wash * 0.1;
	// Darker toward each terrace's foot.
	col *= mix(0.68, 1.0, smoothstep(0.0, 0.5, UV.y));
	// Grass lip draped over the top edge, ragged.
	float lip = smoothstep(0.8 - n2 * 0.2, 0.88 - n2 * 0.18, UV.y);
	col = mix(col, grass * (0.85 + fine * 0.3), lip);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
