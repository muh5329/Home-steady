shader_type spatial;
// Re-grades the KayKit palette texture toward Fabledom's village colours:
// saturated reds become terracotta, pale blue walls become warm plaster,
// deeper blues a muted slate teal, whites a warm cream. Everything else passes through.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 cream = vec3(1.0, 0.93, 0.8);
// 0 = village (bright plaster), 1 = old ruin (whites become weathered,
// mossy grey-ochre stone).
uniform float weathered = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 hsv = rgb2hsv(c);
	float red = (step(hsv.x, 0.05) + step(0.93, hsv.x)) * step(0.35, hsv.y);
	float blue_hue = step(0.5, hsv.x) * step(hsv.x, 0.72);
	// Pale plaster can be barely blue; darker greys with a blue cast are stone.
	float blue = blue_hue * (hsv.z > 0.62 ? step(0.1, hsv.y) : step(0.25, hsv.y));
	float white = step(hsv.y, 0.18) * step(0.7, hsv.z);
	if (red > 0.5) {
		hsv.x = 0.035;
		hsv.y *= 0.82;
		hsv.z = min(hsv.z * 1.05, 1.0);
		c = hsv2rgb(hsv);
	} else if (blue > 0.5) {
		if (hsv.z > 0.62) {
			// Pale blue plaster -> bright sun-warmed ochre plaster (#EACB8A).
			hsv = vec3(0.11, 0.41, min(hsv.z * 1.04, 0.93));
		} else {
			// Shutters, doors, trim: a muted storybook teal.
			hsv.x = 0.48;
			hsv.y = min(hsv.y * 0.6, 0.45);
			hsv.z = min(hsv.z * 1.1, 0.7);
		}
		c = hsv2rgb(hsv);
	} else if (white > 0.5) {
		c *= cream;
	} else if ((hsv.y < 0.12 || (blue_hue > 0.5 && hsv.y < 0.25)) && hsv.z > 0.2) {
		// Grey stone: lighter and sun-warmed, never a cold lump.
		float g = dot(c, vec3(0.299, 0.587, 0.114));
		c = min(vec3(g) * vec3(1.2, 1.12, 0.98), vec3(1.0));
	}
	if (weathered > 0.0) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 stone = vec3(0.4, 0.39, 0.35) * (0.6 + l * 0.4);
		// Moss creeps over surfaces that face the sky.
		float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
		stone = mix(stone, vec3(0.3, 0.42, 0.17), smoothstep(0.3, 0.8, up) * 0.85);
		c = mix(c, stone, weathered * (1.0 - red * 0.6));
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
