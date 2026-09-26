shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// Vertex-coloured stylized foliage (pines, flowers): shading comes from
// the painted vertex colours, with a gentle sway weighted by COLOR.a.
// Everything is kept finite and non-negative: a single NaN pixel turns
// into a black hole once depth of field and glow spread it.

uniform float wind_strength = 0.06;
uniform float saturation = 1.0;
// Chest height of the player (CameraRig keeps it current): foliage between
// the camera and the player dissolves so trees never hide the hero.
global uniform vec3 player_position;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.1 + wp.x * 0.21 + wp.z * 0.17);
	VERTEX.x += sway * wind_strength * COLOR.a * VERTEX.y;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.002, 0.0));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	// Nothing leafy right in front of the lens.
	float near_keep = smoothstep(0.8, 1.8, distance(world_pos, cam));
	if (near_keep < fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.00583)) * 52.9829)) {
		discard;
	}
	vec3 to_player = player_position - cam;
	float len = length(to_player);
	if (len > 0.5 && len < 30.0) {
		vec3 dir = to_player / len;
		float t = dot(world_pos - cam, dir);
		// Near the lens anything goes; closer to the hero only what rises above
		// chest height dissolves, so low flowers beside the path stay solid.
		if (t > 0.0 && t < len - 0.6 && (world_pos.y > player_position.y - 0.2 || t < len * 0.55)) {
			float d = length(world_pos - (cam + dir * t));
			float keep = smoothstep(1.8, 3.4, d);
			float dither = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.00583)) * 52.9829);
			if (keep < dither) {
				discard;
			}
		}
	}
	// Two-sided: Godot flips NORMAL on back faces; foliage keeps its authored
	// normals on both sides so needles and petals don't go dark.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = pow(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));  // vertex colours are sRGB
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(mix(vec3(l), c, saturation), vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.25;
}
