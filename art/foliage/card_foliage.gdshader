shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// Photographic alpha-cut foliage cards (grass, ferns, flowers, leaf
// clusters): wind that grows toward the tips, soft "volume" normals that
// point away from the plant's centre so a crown lights like a round mass,
// translucency, per-instance colour variation and the same camera/hero
// dissolve as the rest of the foliage.
//   COLOR.r = sway weight (0 at the root, 1 at the tip)
//   COLOR.g = AO / depth inside the crown (0 deep, 1 outer shell)
//   CUSTOM0.xyz = volume normal (object space), set by FoliageCards

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_variation = 0.12;
uniform float alpha_cut = 0.45;
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.2;
uniform float translucency = 0.35;
uniform float roughness = 0.85;
uniform float volume_normals = 0.75;
uniform float brightness = 1.0;
global uniform vec3 player_position;

varying vec3 world_pos;
varying float variation;
varying float ao;
varying vec3 card_n;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	variation = hash(origin.xz);
	float sway_w = COLOR.r;
	float t = TIME * wind_speed + origin.x * 0.13 + origin.z * 0.11;
	float gust = sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.3 + sin(t * 5.1 + VERTEX.x * 3.0) * 0.1;
	VERTEX.x += gust * wind_strength * sway_w;
	VERTEX.z += gust * wind_strength * 0.45 * sway_w;
	card_n = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 vol = CUSTOM0.xyz;
	if (dot(vol, vol) > 0.01) {
		NORMAL = normalize(mix(NORMAL, normalize(vol), volume_normals));
	}
	ao = COLOR.g;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	// Cards seen edge-on smear into streaks: cut them away.
	float facing = abs(dot(normalize(card_n), VIEW));
	float cut = mix(0.97, alpha_cut, smoothstep(0.12, 0.4, facing));
	if (tex.a < cut) {
		discard;
	}
	vec3 cam = CAMERA_POSITION_WORLD;
	float dither = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.00583)) * 52.9829);
	if (smoothstep(0.8, 1.8, distance(world_pos, cam)) < dither) {
		discard;
	}
	vec3 to_player = player_position - cam;
	float len = length(to_player);
	if (len > 0.5 && len < 60.0) {
		vec3 dir = to_player / len;
		float along = dot(world_pos - cam, dir);
		if (along > 0.0 && along < len - 0.6 && (world_pos.y > player_position.y - 0.2 || along < len * 0.55)) {
			float d = length(world_pos - (cam + dir * along));
			if (smoothstep(1.8, 3.4, d) < dither) {
				discard;
			}
		}
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = tex.rgb * tint;
	// Some plants a little yellower / darker than their neighbours.
	c *= mix(vec3(1.0 - tint_variation, 1.0 - tint_variation * 0.5, 1.0 - tint_variation),
			vec3(1.0 + tint_variation * 0.6, 1.0 + tint_variation * 0.3, 1.0 - tint_variation * 0.5), variation);
	ALBEDO = clamp(c * brightness, vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	AO = mix(0.35, 1.0, ao);
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = c * translucency;
}
