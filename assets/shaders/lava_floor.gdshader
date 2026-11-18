// Lava venue floor: dark cooled crust broken by glowing cracks that slowly shift and pulse,
// fading into the smoky haze far away. Lights itself, so it can fade into its own haze.
// Written by Claude Code (AI-generated art; see assets/CREDITS.md).
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec3 crust_color : source_color = vec3(0.09, 0.05, 0.05);
uniform vec3 lava_color : source_color = vec3(1.0, 0.32, 0.04);
uniform vec3 hot_color : source_color = vec3(1.0, 0.8, 0.3);
// Brightness of the lava; above 1 it blooms.
uniform float glow = 2.2;
// Crust plates per meter.
uniform float crack_scale = 0.012;
uniform float flow_speed = 0.02;
uniform vec3 haze_color : source_color = vec3(0.45, 0.14, 0.06);
uniform float haze_density = 0.0005;
uniform vec3 light_direction = vec3(0.4, 0.7, 0.6);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Distance to the nearest border between Voronoi cells (0 on a border): the crack network.
float crack_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 to_point = offset + hash22(cell + offset) - local;
			float d = dot(to_point, to_point);
			if (d < nearest) {
				second = nearest;
				nearest = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return sqrt(second) - sqrt(nearest);
}

void fragment() {
	vec2 p = world_position.xz * crack_scale;
	vec2 flow = vec2(1.0, 0.6) * TIME * flow_speed;
	float wide = 1.0 - smoothstep(0.0, 0.09, crack_distance(p + fbm2(p * 2.0) * 0.4));
	float fine = (1.0 - smoothstep(0.0, 0.06, crack_distance(p * 3.1 + flow))) * 0.5;
	float heat = clamp(wide + fine, 0.0, 1.0);
	float pulse = 0.8 + 0.2 * sin(TIME * 1.3 + p.x * 3.0 + p.y * 2.0);
	vec3 crust = crust_color * (0.7 + 0.3 * fbm2(p * 6.0)) * (0.7 + 0.3 * max(normalize(light_direction).y, 0.0));
	vec3 lava = mix(lava_color, hot_color, wide * 0.6) * glow * pulse;
	vec3 color = mix(crust, lava, heat);
	float haze = haze_amount(length(world_position - CAMERA_POSITION_WORLD), haze_density);
	ALBEDO = mix(color, haze_color, haze);
}
