shader_type canvas_item;
// Shows the flat map as if tilted away from the viewer: rows toward the
// top are foreshortened and widened (a true perspective divide), with a
// hazy sky-sea horizon glow at the far edge, like the storybook overworld.

uniform float tilt = 0.85;      // 0 = flat; larger = steeper perspective
uniform float far_widen = 1.5; // how much more world the top row spans

void fragment() {
	// Perspective mapping of screen rows to map rows.
	float v = UV.y;
	// Far rows (top) are foreshortened: each pixel covers more map.
	float src_y = v * (1.0 + tilt) / (1.0 + tilt * v);
	src_y = clamp(src_y * 0.94 + 0.03, 0.0, 1.0);
	float widen = mix(far_widen, 1.0, v);
	float src_x = 0.5 + (UV.x - 0.5) * widen;
	vec4 c = texture(TEXTURE, vec2(clamp(src_x, 0.0, 1.0), src_y));
	// Aerial haze toward the horizon.
	float haze = smoothstep(0.35, 0.0, v);
	c.rgb = mix(c.rgb, vec3(0.78, 0.92, 0.9), haze * 0.45);
	COLOR = vec4(c.rgb, 1.0);
}
