// Far-off peaks for the Snow, Lava and Desert venues (see MountainRing): faceted low-poly
// cones, rock below and snow (or glowing lava, or pale cap rock) at the top, optionally banded
// with rock layers, fading into the haze. Lights itself, so it can fade into its own haze
// instead of the cube's fog.
// Written by Claude Code (AI-generated art; see assets/CREDITS.md).
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 rock_color : source_color = vec3(0.42, 0.47, 0.58);
uniform vec3 peak_color : source_color = vec3(0.97, 0.98, 1.0);
// Fraction of the height where the peak color starts.
uniform float peak_line = 0.55;
// More than 0 makes the peak glow (lava) instead of being lit by the sun.
uniform float peak_glow = 0.0;
// More than 0 bands the rock with horizontal layers of different shades (desert mesas).
uniform float strata = 0.0;
// How many layers from base to top.
uniform float strata_count = 9.0;
// Share of light that reaches faces turned away from the sun.
uniform float ambient = 0.45;
uniform vec3 haze_color : source_color = vec3(0.88, 0.93, 1.0);
uniform float haze_density = 0.0005;
// Set by Scenery from the venue's sun.
uniform vec3 light_direction = vec3(0.4, 0.7, 0.6);

#include "res://assets/shaders/noise.gdshaderinc"

varying vec3 world_position;
// 0 at the base, 1 at the tip: the mesh is a unit cone, scaled per peak.
varying float height;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = VERTEX.y + 0.5;
}

void fragment() {
	// One normal per face, for the faceted low-poly look.
	vec3 normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(normal, CAMERA_POSITION_WORLD - world_position) < 0.0) {
		normal = -normal;
	}
	float light = ambient + (1.0 - ambient) * max(dot(normal, normalize(light_direction)), 0.0);
	float wobble = (noise2(world_position.xz * 0.02) - 0.5) * 0.12;
	float peak = smoothstep(peak_line - 0.02, peak_line + 0.02, height + wobble);
	vec3 lit_peak = peak_color * mix(light, 1.0 + peak_glow, step(0.001, peak_glow));
	float layer = hash21(vec2(floor((height + wobble * 0.15) * strata_count), 3.7));
	vec3 rock = rock_color * (1.0 - strata * layer);
	vec3 color = mix(rock * light, lit_peak, peak);
	float haze = haze_amount(length(world_position - CAMERA_POSITION_WORLD), haze_density);
	ALBEDO = mix(color, haze_color, haze);
}
