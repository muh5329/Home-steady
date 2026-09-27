shader_type spatial;
// Re-grades the KayKit palette texture toward Fabledom's village colours:
// reds become saturated orange roofs, pale blue walls become the building's
// plaster colour, deeper blues teal doors and shutters, whites warm cream,
// greys warm stone. Everything else passes through.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 cream = vec3(1.0, 0.95, 0.86);
// Wall plaster (HSV, sRGB): ochre #E6C06A by default; buildings vary it
// (cream, pale pink) so a street isn't one colour.
uniform vec3 wall_hsv = vec3(0.114, 0.54, 0.90);
// Buildings: white plaster takes the wall colour too.
uniform bool whites_are_plaster = false;
// Target for saturated reds (HSV, sRGB): orange roofs #D4602A; characters
// use a softer brick #B8433A so capes don't shout.
uniform vec3 red_hsv = vec3(0.054, 0.78, 0.83);
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
	vec3 lin = texture(albedo_tex, UV).rgb;
	// Classify and remap in sRGB, where the target colours are picked.
	vec3 c = pow(lin, vec3(1.0 / 2.2));
	vec3 hsv = rgb2hsv(c);
	float red = (step(hsv.x, 0.05) + step(0.93, hsv.x)) * step(0.45, hsv.y);
	float blue_hue = step(0.5, hsv.x) * step(hsv.x, 0.72);
	bool pale_blue = blue_hue > 0.5 && hsv.z > 0.8 && hsv.y > 0.08;
	bool deep_blue = blue_hue > 0.5 && !pale_blue && hsv.y > 0.3;
	bool white = hsv.y < 0.12 && hsv.z > 0.85;
	bool grey = !white && hsv.z > 0.25 && (hsv.y < 0.1 || (blue_hue > 0.5 && hsv.y <= 0.3));
	if (red > 0.5) {
		// Roofs and awnings: saturated storybook orange (#D4602A).
		c = hsv2rgb(vec3(red_hsv.x, red_hsv.y, clamp(red_hsv.z * hsv.z / 0.85, 0.3, 0.92)));
	} else if (pale_blue || (white && whites_are_plaster)) {
		// Plaster walls take the building's wall colour, keeping the
		// texture's light and shade.
		c = hsv2rgb(vec3(wall_hsv.x, wall_hsv.y, clamp(wall_hsv.z * hsv.z / 0.9, 0.3, 0.97)));
	} else if (deep_blue) {
		// Doors, shutters, trim: saturated teal (#3F8C8A), big enough to read.
		c = hsv2rgb(vec3(0.496, 0.55, clamp(hsv.z * 0.9, 0.35, 0.62)));
	} else if (white) {
		c *= cream;
	} else if (grey) {
		// Stone: warm, and a touch darker so chimneys and forges recede.
		float g = dot(c, vec3(0.299, 0.587, 0.114));
		c = clamp(vec3(g) * vec3(1.02, 0.96, 0.86), vec3(0.0), vec3(1.0));
	}
	c = pow(c, vec3(2.2));
	if (weathered > 0.0) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 stone = vec3(0.4, 0.39, 0.35) * (0.6 + l * 0.4);
		// Moss creeps over surfaces that face the sky.
		float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
		stone = mix(stone, vec3(0.3, 0.42, 0.17), smoothstep(0.3, 0.8, up) * 0.85);
		c = mix(c, stone, weathered * (1.0 - red * 0.6));
	}
	ALBEDO = c;
	ROUGHNESS = red_hsv.z < 0.8 ? 1.0 : 0.85;
	SPECULAR = 0.25;
}
