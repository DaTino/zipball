// Desert venue floor: long dunes with gentle windward slopes and steep, shaded slip faces,
// wind ripples, and paler flats between dune fields, fading into the haze far away. Lights
// itself, so it can fade into its own haze instead of the cube's fog.
// Written by Claude Code (AI-generated art; see assets/CREDITS.md).
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec3 sand_color : source_color = vec3(0.95, 0.74, 0.47);
uniform vec3 shadow_color : source_color = vec3(0.66, 0.4, 0.27);
uniform vec3 flat_color : source_color = vec3(0.86, 0.72, 0.55);
// Dune crests per meter, along the wind.
uniform float dune_scale = 0.006;
// Dune height (m) where they're biggest.
uniform float dune_height = 35.0;
// Which way the wind blows (x, z). Slip faces face downwind.
uniform vec2 wind = vec2(-0.5, 0.87);
uniform vec3 haze_color : source_color = vec3(0.9, 0.8, 0.64);
uniform float haze_density = 0.0005;
// Set by Scenery from the venue's sun.
uniform vec3 light_direction = vec3(0.4, 0.7, 0.6);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 0 on the flats, 1 where the dunes are biggest.
float dune_field(vec2 p) {
	return smoothstep(0.32, 0.62, fbm2(p * 0.0008 + 7.0));
}

// Share of each dune that is the gentle windward side; the rest is the steep slip face.
const float WINDWARD = 0.78;

void fragment() {
	vec2 p = world_position.xz;
	vec2 w = normalize(wind);
	vec2 across = vec2(-w.y, w.x);

	// Crests run across the wind, wandering a little. Each dune climbs slowly up its windward
	// side and drops down a short slip face. The slope comes from that profile alone, so the
	// noise that bends the crests doesn't show up as creases in the light.
	float phase = dot(p, w) * dune_scale + fbm2(p * 0.0011) * 2.2 + sin(dot(p, across) * 0.0021) * 0.6;
	float t = fract(phase);
	float rising = t < WINDWARD ? 1.0 : 0.0;
	float s = mix((1.0 - t) / (1.0 - WINDWARD), t / WINDWARD, rising);
	float steepness = 6.0 * s * (1.0 - s) * mix(-1.0 / (1.0 - WINDWARD), 1.0 / WINDWARD, rising);
	float field = dune_field(p);
	float slope = steepness * dune_scale * dune_height * field; // Rise per meter along the wind.
	vec3 normal = normalize(vec3(-w.x * slope, 1.0, -w.y * slope));
	float sun = max(dot(normal, normalize(light_direction)), 0.0);

	// Fine ripples across the wind, faded out far away where they would shimmer.
	float ripple_phase = dot(p, w) * 0.25 + fbm2(p * 0.02) * 3.0;
	float ripple = sin(ripple_phase * TAU) * 0.5 + 0.5;
	ripple *= 1.0 - smoothstep(0.1, 0.35, fwidth(ripple_phase));

	vec3 base = mix(flat_color, sand_color, field);
	vec3 color = mix(shadow_color, base, smoothstep(0.2, 0.8, sun)) * (0.82 + 0.18 * sun);
	color *= 1.0 - 0.07 * ripple;
	float haze = haze_amount(length(world_position - CAMERA_POSITION_WORLD), haze_density);
	ALBEDO = mix(color, haze_color, haze);
}
