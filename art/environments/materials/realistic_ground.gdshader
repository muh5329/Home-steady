shader_type spatial;
// Photographic ground (CC0 ambientCG / Poly Haven scans): a meadow of
// mixed grass and bare earth, with dirt roads, cobbled streets, tilled
// fields and sand painted in from TerrainPainter's world-space mask
// (R = dirt road, G = cobblestone, B = tilled soil, A = sand).
// Tiling is hidden by sampling each surface twice at unrelated scales and
// rotations and blending with large-scale noise; transitions are
// height-aware (grass creeps into cobble joints, not over the stones).

uniform sampler2D noise_large : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_small : repeat_enable, filter_linear_mipmap;
uniform sampler2D paint_mask : filter_linear, repeat_disable, hint_default_black;
uniform vec4 mask_rect = vec4(-80.0, -80.0, 160.0, 160.0);
// Rivers (River) sink the ground: R = 0 dry .. 1 deepest.
uniform sampler2D water_mask : filter_linear, repeat_disable, hint_default_black;
uniform vec4 water_rect = vec4(-130.0, -130.0, 260.0, 260.0);
uniform float water_depth = 0.0;
// The far ground skips the area the near (detailed) ground covers.
uniform vec4 hole_rect = vec4(0.0);

uniform sampler2D meadow_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D meadow_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D cobble_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D cobble_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D cobble_ao : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;

// Metres covered by one repeat of each texture.
uniform float meadow_size = 3.2;
uniform float grass_size = 2.2;
uniform float dirt_size = 2.6;
uniform float cobble_size = 1.55;
uniform float soil_size = 2.4;
uniform float sand_size = 2.8;
// Overall grading toward the references' warm late-afternoon look.
uniform vec3 grass_tint : source_color = vec3(1.0, 1.0, 0.92);
uniform float grass_share = 0.95;

varying vec3 world_pos;
varying float wet;

float water_at(vec2 xz) {
	vec2 uv = (xz - water_rect.xy) / water_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(water_mask, uv).r;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = water_at(wp.xz);
	if (water_depth > 0.0) {
		VERTEX.y -= w * water_depth;
		// Bank slope normal from the mask gradient.
		float e = 1.0;
		float dx = (water_at(wp.xz + vec2(e, 0.0)) - water_at(wp.xz - vec2(e, 0.0))) * water_depth / (2.0 * e);
		float dz = (water_at(wp.xz + vec2(0.0, e)) - water_at(wp.xz - vec2(0.0, e))) * water_depth / (2.0 * e);
		NORMAL = normalize(vec3(dx, 1.0, dz));
	}
	wet = w;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Two decorrelated samples of a tiling texture, blended by noise.
vec4 sample2(sampler2D t, vec2 p, float size, float blend) {
	vec4 a = texture(t, p / size);
	vec4 b = texture(t, rot(p, 1.13) / (size * 1.37) + vec2(0.37, 0.61));
	return mix(a, b, blend);
}

vec3 normal2(sampler2D t, vec2 p, float size, float blend) {
	vec3 a = texture(t, p / size).xyz;
	vec3 b = texture(t, rot(p, 1.13) / (size * 1.37) + vec2(0.37, 0.61)).xyz;
	return mix(a, b, blend);
}

void fragment() {
	vec2 p = world_pos.xz;
	if (hole_rect.z > 0.0 && p.x > hole_rect.x && p.y > hole_rect.y && p.x < hole_rect.x + hole_rect.z && p.y < hole_rect.y + hole_rect.w) {
		discard;
	}
	float n1 = texture(noise_large, p * 0.012).r;
	float n2 = texture(noise_large, p * 0.041 + vec2(0.31, 0.7)).r;
	float fine = texture(noise_small, p * 0.35).r;
	float mixer = smoothstep(0.3, 0.7, texture(noise_large, p * 0.023 + vec2(0.5, 0.2)).r);

	// Meadow: photographed grass-and-earth, with lusher patches of pure grass.
	vec3 meadow = sample2(meadow_albedo, p, meadow_size, mixer).rgb;
	vec3 meadow_n = normal2(meadow_normal, p, meadow_size, mixer);
	vec3 lush = sample2(grass_albedo, p, grass_size, 1.0 - mixer).rgb;
	vec3 lush_n = normal2(grass_normal, p, grass_size, 1.0 - mixer);
	float lushness = smoothstep(0.5 - grass_share * 0.5, 0.75 - grass_share * 0.4, n1 + (fine - 0.5) * 0.25);
	// The photographed lawn is a touch dark and blue; warm it toward the
	// sunlit meadows in the references.
	// Keep the bare-earth patches of the meadow scan, but not its yellow cast.
	float ml = dot(meadow, vec3(0.3, 0.59, 0.11));
	meadow = mix(meadow, vec3(ml) * vec3(0.86, 1.05, 0.6), 0.5);
	vec3 col = mix(meadow, lush * vec3(1.08, 1.12, 0.78), lushness);
	vec3 nrm = mix(meadow_n, lush_n, lushness);
	// Broad sun-bleached and shaded sweeps.
	col *= mix(0.965, 1.035, n2);
	col *= grass_tint;

	vec2 muv = (p - mask_rect.xy) / mask_rect.zw;
	vec4 mask = texture(paint_mask, muv);
	if (muv.x < 0.0 || muv.y < 0.0 || muv.x > 1.0 || muv.y > 1.0) {
		mask = vec4(0.0);
	}
	float grit = texture(noise_small, p * 1.7 + vec2(0.13, 0.71)).r;
	float edge = (n2 - 0.5) * 0.35 + (fine - 0.5) * 0.3 + (grit - 0.5) * 0.3;

	// Dirt road: raked, trodden earth.
	vec3 dirt = sample2(dirt_albedo, p, dirt_size, mixer).rgb * vec3(1.05, 1.0, 0.92);
	vec3 dirt_n = normal2(dirt_normal, p, dirt_size, mixer);
	float road = smoothstep(0.32, 0.6, mask.r + edge);
	// Worn middle is paler and dustier; the margins darker and trodden.
	dirt *= mix(0.82, 1.08, smoothstep(0.55, 0.95, mask.r));
	col = mix(col, dirt, road);
	nrm = mix(nrm, dirt_n, road);

	// Cobblestones: the grass creeps into the joints first.
	vec3 cob = texture(cobble_albedo, p / cobble_size).rgb;
	vec3 cob_n = texture(cobble_normal, p / cobble_size).xyz;
	float cob_h = texture(cobble_ao, p / cobble_size).r;
	float cobble = smoothstep(0.3, 0.55, mask.g + edge * 0.5 + (cob_h - 0.6) * 0.8);
	// Worn stretches: stones lost or sunk, trodden earth between the rest.
	float wear = smoothstep(0.42, 0.72, texture(noise_large, p * 0.075 + vec2(0.2, 0.9)).r + (fine - 0.5) * 0.35);
	float keep = smoothstep(0.38, 0.62, cob_h + 0.35 - wear * 0.7);
	float cob_region = smoothstep(0.3, 0.55, mask.g + edge * 0.5);
	col = mix(col, dirt * 0.92, cob_region * wear * (1.0 - keep));
	nrm = mix(nrm, dirt_n, cob_region * wear * (1.0 - keep));
	cobble *= mix(1.0, keep, wear);
	// Weathered grey-beige limestone rather than the scan's warm brown.
	float cl = dot(cob, vec3(0.3, 0.59, 0.11));
	cob = mix(cob, vec3(cl) * vec3(1.06, 1.02, 0.94), 0.35);
	cob *= mix(0.85, 1.08, n2);
	// Dark, dirt-filled joints.
	cob *= mix(0.5, 1.0, smoothstep(0.25, 0.6, cob_h));
	col = mix(col, cob, cobble);
	nrm = mix(nrm, cob_n, cobble);

	// Tilled soil.
	vec3 soil = sample2(soil_albedo, p, soil_size, mixer).rgb;
	vec3 soil_n = normal2(soil_normal, p, soil_size, mixer);
	float tilled = smoothstep(0.4, 0.6, mask.b + edge * 0.4);
	col = mix(col, soil, tilled);
	nrm = mix(nrm, soil_n, tilled);

	// Sand banks.
	vec3 sand = sample2(sand_albedo, p, sand_size, mixer).rgb * vec3(1.08, 1.02, 0.9);
	vec3 sand_n = normal2(sand_normal, p, sand_size, mixer);
	float sandy = smoothstep(0.3, 0.6, mask.a + edge * 0.6);
	col = mix(col, sand, sandy);
	nrm = mix(nrm, sand_n, sandy);

	// River bed: wet, darker sand with weed and pebbles going deeper.
	float wet_edge = smoothstep(0.0, 0.12, wet);
	col = mix(col, sand * vec3(0.72, 0.68, 0.58), wet_edge * 0.8);
	col = mix(col, vec3(0.22, 0.26, 0.16), smoothstep(0.45, 1.0, wet) * 0.6 * mixer);
	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(mix(0.95, 0.8, cobble), 0.35, wet_edge * (1.0 - smoothstep(0.1, 0.3, wet)) * 0.0 + wet_edge * 0.4);
	SPECULAR = 0.3;
	AO = mix(1.0, cob_h, cobble * 0.8);
	AO_LIGHT_AFFECT = 0.4;
}
