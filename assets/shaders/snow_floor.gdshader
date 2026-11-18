// Snow venue floor: rolling white drifts with blue hollows and wind ripples, fading into the
// haze far away. Lights itself, so it can fade into its own haze instead of the cube's fog.
// Written by Claude Code (AI-generated art; see assets/CREDITS.md).
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec3 snow_color : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 hollow_color : source_color = vec3(0.68, 0.78, 0.94);
// Drifts per meter.
uniform float drift_scale = 0.004;
uniform vec3 haze_color : source_color = vec3(0.88, 0.93, 1.0);
uniform float haze_density = 0.0005;
// Set by Scenery from the venue's sun.
uniform vec3 light_direction = vec3(0.4, 0.7, 0.6);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float drifts = fbm2(p * drift_scale);
	float ripples = sin(p.x * 0.05 + p.y * 0.02 + fbm2(p * 0.01) * 6.0) * 0.5 + 0.5;
	float snow = smoothstep(0.35, 0.65, drifts) * 0.85 + ripples * 0.15;
	float light = 0.75 + 0.25 * max(normalize(light_direction).y, 0.0);
	vec3 color = mix(hollow_color, snow_color, snow) * light;
	float haze = haze_amount(length(world_position - CAMERA_POSITION_WORLD), haze_density);
	ALBEDO = mix(color, haze_color, haze);
}
