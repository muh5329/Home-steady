shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Clear, sunlit water in the references' style: see-through turquoise
// shallows over the sandy/weedy bed, deepening to green-blue, a bright
// fresnel sky sheen, sparkling sun glints on two scrolling ripple layers,
// soft foam where it laps the bank, and refraction of whatever is below.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;

uniform vec3 shallow_color : source_color = vec3(0.5, 0.65, 0.57);
uniform vec3 deep_color : source_color = vec3(0.17, 0.26, 0.24);
uniform vec3 sky_color : source_color = vec3(0.84, 0.86, 0.84);
uniform float clarity = 2.4;          // metres of water before it goes opaque
uniform float refraction = 0.035;
uniform float ripple_scale = 0.09;
uniform vec2 flow = vec2(0.0, 0.035);  // metres per second (river current)
uniform float foam_width = 0.22;
uniform float normal_strength = 0.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 ndc = vec4(uv * 2.0 - 1.0, d, 1.0);
	vec4 view = inv_proj * ndc;
	return -view.z / view.w;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 na = texture(ripple_a, p * ripple_scale + flow * TIME * 0.8).xyz * 2.0 - 1.0;
	vec3 nb = texture(ripple_b, p * ripple_scale * 2.3 - flow.yx * TIME * 1.3 + vec2(0.3, 0.7)).xyz * 2.0 - 1.0;
	vec3 n = normalize(vec3((na.xy + nb.xy) * normal_strength, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// Water thickness along the view ray (from the depth buffer).
	float surface = -VERTEX.z;
	float floor_d = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float thick = max(floor_d - surface, 0.0);
	vec2 ruv = SCREEN_UV + n.xy * refraction * clamp(thick, 0.0, 1.0);
	// Don't refract things in front of the water.
	float floor_r = linear_depth(ruv, INV_PROJECTION_MATRIX);
	if (floor_r < surface) {
		ruv = SCREEN_UV;
		floor_r = floor_d;
	}
	thick = max(floor_r - surface, 0.0);
	vec3 below = textureLod(screen_tex, ruv, 0.0).rgb;

	float t = 1.0 - exp(-thick / clarity);
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.15, 1.0, t));
	// What shows through (already lit) is emitted; the water body itself
	// is a lit albedo, so sun and shade still play on it.
	vec3 transmitted = below * mix(vec3(1.0), shallow_color * 1.25, 0.6) * (1.0 - t);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);

	float fn = texture(foam_noise, p * 0.35 + vec2(TIME * 0.02, 0.0)).r;
	float foam = (1.0 - smoothstep(0.0, foam_width, thick)) * smoothstep(0.35, 0.6, fn + 0.25 * sin(TIME * 1.5 + p.x * 0.7));

	ALBEDO = mix(water * t, vec3(0.9, 0.93, 0.92), foam * 0.7);
	EMISSION = transmitted * (1.0 - foam * 0.7) * (1.0 - fres * 0.5) + sky_color * (0.035 + fres * 0.55);
	ROUGHNESS = mix(0.08, 0.4, foam);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	// Fade the very edge into the bank.
	ALPHA = clamp(smoothstep(0.0, 0.08, thick) * 0.97 + foam * 0.2, 0.0, 1.0);
}
