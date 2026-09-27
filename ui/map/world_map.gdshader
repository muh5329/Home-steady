shader_type canvas_item;
// Illustrated world map (Cat Quest style): bright storybook greens, a
// turquoise river with pale shallows and a dark rim, sandy beaches and
// tan roads from the ground's paint mask, soft painted texture.

uniform sampler2D paint_mask : filter_linear;
uniform vec4 mask_rect = vec4(-80.0, -80.0, 160.0, 160.0);
uniform sampler2D water_mask : filter_linear, hint_default_black;
uniform vec4 water_rect = vec4(-130.0, -130.0, 260.0, 260.0);
uniform sampler2D noise : repeat_enable, filter_linear;
// World rect shown: min corner (x, z) and size.
uniform vec4 view_rect = vec4(-130.0, -130.0, 260.0, 260.0);

vec4 paint_at(vec2 w) {
	vec2 uv = (w - mask_rect.xy) / mask_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(paint_mask, uv);
}

float water_at(vec2 w) {
	vec2 uv = (w - water_rect.xy) / water_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(water_mask, uv).r;
}

// The land is an island in a bright sea, like the storybook overworld.
float coast_at(vec2 w, float n, float n2) {
	// Two scales of noise give bays and headlands, not a round blob.
	float bays = texture(noise, w * 0.0021 + vec2(0.13, 0.57)).r;
	return length(w / vec2(150.0, 140.0)) + (n - 0.5) * 0.26 + (bays - 0.5) * 0.34;
}

void fragment() {
	vec2 w = view_rect.xy + UV * view_rect.zw;
	float n = texture(noise, w * 0.004).r;
	float n2 = texture(noise, w * 0.02 + vec2(0.4, 0.1)).r;
	float n3 = texture(noise, w * 0.06 + vec2(0.7, 0.3)).r;
	// Land: bright yellow-green, lighter meadows, darker lowlands, and soft
	// painted strokes running across it.
	vec3 land = mix(vec3(0.36, 0.62, 0.14), vec3(0.62, 0.8, 0.22), smoothstep(0.35, 0.75, n));
	land = mix(land, land * 0.86, smoothstep(0.6, 0.9, n2) * 0.5);
	float stroke = smoothstep(0.45, 0.5, fract((w.x * 0.7 + w.y * 0.25 + n2 * 18.0) * 0.12));
	land *= 0.97 + stroke * 0.05 * smoothstep(0.4, 0.7, n3);
	vec3 col = land;
	vec4 m = paint_at(w);
	// Beaches.
	col = mix(col, vec3(0.93, 0.85, 0.6), smoothstep(0.3, 0.6, m.a));
	// Roads: thin ochre paths with a darker edge.
	float road = max(m.r, m.g);
	col = mix(col, vec3(0.55, 0.42, 0.2), smoothstep(0.3, 0.45, road) * (1.0 - smoothstep(0.45, 0.6, road)));
	col = mix(col, vec3(0.86, 0.74, 0.44), smoothstep(0.5, 0.7, road));
	col = mix(col, vec3(0.62, 0.45, 0.25), smoothstep(0.4, 0.6, m.b));
	// Water: dark rim, turquoise body, pale shallows.
	float wv = water_at(w);
	// Past the ground's water mask the river runs on out to the sea.
	if (abs(w.y) > 100.0) {
		float cx = 33.0 + sin(w.y * 0.03) * 2.0;
		wv = max(wv, smoothstep(7.0, 3.0, abs(w.x - cx)) * smoothstep(100.0, 110.0, abs(w.y)));
	}
	// Two woodland lakes (map-only: the playable valley has none yet).
	float lake_a = length((w - vec2(-82.0, -58.0)) / vec2(17.0, 11.0)) + (n2 - 0.5) * 0.5;
	float lake_b = length((w - vec2(78.0, 72.0)) / vec2(13.0, 9.0)) + (n2 - 0.5) * 0.5;
	float lake = 1.0 - min(lake_a, lake_b);
	wv = max(wv, smoothstep(0.0, 0.5, lake));
	col = mix(col, vec3(0.12, 0.4, 0.3), smoothstep(0.0, 0.05, wv) * (1.0 - smoothstep(0.05, 0.15, wv)));
	vec3 water = mix(vec3(0.42, 0.85, 0.72), vec3(0.16, 0.66, 0.6), smoothstep(0.2, 0.9, wv));
	col = mix(col, water, smoothstep(0.08, 0.16, wv));
	// Coast: a pale sand rim, a dark lip, luminous shallows, then deep sea.
	float c = coast_at(w, n, n2);
	vec3 sea = mix(vec3(0.3, 0.78, 0.58), vec3(0.08, 0.56, 0.46), smoothstep(1.02, 1.3, c));
	col = mix(col, vec3(0.94, 0.88, 0.64), smoothstep(0.945, 0.96, c));
	col = mix(col, vec3(0.2, 0.42, 0.24), smoothstep(0.985, 0.992, c) * (1.0 - smoothstep(0.995, 1.0, c)));
	col = mix(col, sea, smoothstep(0.995, 1.0, c));
	// Paper grain and a vignette.
	col *= 0.95 + n2 * 0.08;
	vec2 v = UV * 2.0 - 1.0;
	col *= 1.0 - dot(v, v) * 0.1;
	COLOR = vec4(col, 1.0);
}
