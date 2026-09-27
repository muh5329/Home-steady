shader_type canvas_item;
// Minimap: a grey-green map from the ground's paint mask (R road, G cobble,
// B tilled, A sand) and the river mask, cut to a circle with a soft vignette.

uniform sampler2D paint_mask : filter_linear;
uniform vec4 mask_rect = vec4(-80.0, -80.0, 160.0, 160.0);
uniform sampler2D water_mask : filter_linear, hint_default_black;
uniform vec4 water_rect = vec4(-130.0, -130.0, 260.0, 260.0);
uniform vec2 centre = vec2(0.0);
uniform float world_radius = 55.0;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	if (r > 1.0) {
		discard;
	}
	vec2 w = centre + d * world_radius;
	vec2 muv = (w - mask_rect.xy) / mask_rect.zw;
	vec4 m = vec4(0.0);
	if (muv.x >= 0.0 && muv.y >= 0.0 && muv.x <= 1.0 && muv.y <= 1.0) {
		m = texture(paint_mask, muv);
	}
	vec2 wuv = (w - water_rect.xy) / water_rect.zw;
	float water = 0.0;
	if (wuv.x >= 0.0 && wuv.y >= 0.0 && wuv.x <= 1.0 && wuv.y <= 1.0) {
		water = texture(water_mask, wuv).r;
	}
	vec3 land = vec3(0.36, 0.38, 0.32);
	vec3 col = land;
	col = mix(col, vec3(0.62, 0.58, 0.5), smoothstep(0.3, 0.6, m.a));
	col = mix(col, vec3(0.66, 0.6, 0.5), smoothstep(0.3, 0.6, m.r));
	col = mix(col, vec3(0.74, 0.72, 0.68), smoothstep(0.3, 0.6, m.g));
	col = mix(col, vec3(0.42, 0.33, 0.24), smoothstep(0.4, 0.6, m.b));
	col = mix(col, vec3(0.27, 0.42, 0.48), smoothstep(0.05, 0.3, water));
	// Outside the known land: fog of the unexplored.
	float known = step(0.0, muv.x) * step(0.0, muv.y) * step(muv.x, 1.0) * step(muv.y, 1.0);
	col = mix(vec3(0.2, 0.21, 0.19), col, known);
	col *= 1.0 - smoothstep(0.6, 1.0, r) * 0.35;
	COLOR = vec4(col, 0.95);
}
