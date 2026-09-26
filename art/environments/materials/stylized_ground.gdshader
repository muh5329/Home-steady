shader_type spatial;
render_mode cull_disabled;
// Painterly ground in the Fabledom mould: warm sunlit grass in broad
// colour sweeps with brush-like streaks, plus painted-in dirt roads,
// cobbled plazas and tilled soil from a world-space paint mask
// (R = dirt road, G = cobblestone, B = tilled soil) baked by TerrainPainter.

uniform vec3 grass_lush : source_color = vec3(0.38, 0.54, 0.16);
uniform vec3 grass_deep : source_color = vec3(0.23, 0.39, 0.12);
uniform vec3 grass_warm : source_color = vec3(0.60, 0.58, 0.22);
uniform vec3 grass_tip : source_color = vec3(0.62, 0.64, 0.26);
uniform vec3 dirt_light : source_color = vec3(0.74, 0.59, 0.40);
uniform vec3 dirt_dark : source_color = vec3(0.52, 0.38, 0.25);
uniform vec3 stone_light : source_color = vec3(0.70, 0.72, 0.76);
uniform vec3 stone_dark : source_color = vec3(0.46, 0.50, 0.58);
uniform vec3 soil : source_color = vec3(0.34, 0.21, 0.13);
uniform sampler2D noise_large : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_small : repeat_enable, filter_linear_mipmap;
uniform sampler2D paint_mask : filter_linear, repeat_disable, hint_default_black;
// World-space rectangle the mask covers: xy = min corner (x, z), zw = size.
uniform vec4 mask_rect = vec4(-80.0, -80.0, 160.0, 160.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Cobblestone cells: returns (distance to cell edge, cell random).
vec2 cobbles(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float second = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 h = fract(sin(vec2(dot(i + g, vec2(127.1, 311.7)), dot(i + g, vec2(269.5, 183.3)))) * 43758.5453);
			vec2 r = g + 0.15 + h * 0.7 - f;
			float d = dot(r, r);
			if (d < best) { second = best; best = d; id = h.x; }
			else if (d < second) { second = d; }
		}
	}
	return vec2(sqrt(second) - sqrt(best), id);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n1 = texture(noise_large, p * 0.010).r;
	float n2 = texture(noise_large, p * 0.037 + vec2(0.31, 0.7)).r;
	// Brush streaks: noise squashed along one direction.
	float streak = texture(noise_small, vec2(p.x * 0.09, p.y * 0.5)).r;
	float fine = texture(noise_small, p * 0.6).r;

	vec3 grass = mix(grass_deep, grass_lush, smoothstep(0.30, 0.62, n1));
	grass = mix(grass, grass_warm, smoothstep(0.58, 0.82, n2) * 0.45);
	grass = mix(grass, grass_tip, smoothstep(0.55, 0.95, streak) * 0.22);
	grass *= 0.88 + fine * 0.22;

	vec2 muv = (p - mask_rect.xy) / mask_rect.zw;
	vec3 mask = texture(paint_mask, muv).rgb;
	if (muv.x < 0.0 || muv.y < 0.0 || muv.x > 1.0 || muv.y > 1.0) {
		mask = vec3(0.0);
	}
	// Ragged painted edges.
	float edge = (n2 - 0.5) * 0.35 + (fine - 0.5) * 0.25;
	float road = smoothstep(0.35, 0.62, mask.r + edge);
	float cobble = smoothstep(0.35, 0.6, mask.g + edge * 0.6);
	float tilled = smoothstep(0.4, 0.6, mask.b + edge * 0.4);

	vec3 col = grass;
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.2, 0.8, n2 * 0.6 + fine * 0.4));
	// Worn, paler middle; darker, grassier shoulders.
	dirt = mix(dirt * 0.85, dirt * 1.08, smoothstep(0.7, 1.0, mask.r));
	col = mix(col, dirt, road);
	vec2 c = cobbles(p * 1.15);
	vec3 stone = mix(stone_dark, stone_light, c.y * 0.7 + fine * 0.2);
	// Rounded stones: lighter crowns, dark grout between.
	stone *= 0.8 + 0.3 * smoothstep(0.05, 0.4, c.x);
	stone = mix(vec3(0.22, 0.2, 0.2), stone, smoothstep(0.03, 0.1, c.x));
	col = mix(col, stone, cobble);
	float furrow = sin(p.x * 3.2 + n2 * 2.0) * 0.5 + 0.5;
	col = mix(col, soil * (0.7 + furrow * 0.5), tilled);

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.75, cobble);
	SPECULAR = 0.15;
}
