// Space venue sky: stars, two faint nebula clouds, the sun, and a big banded planet below that
// stands in for the floor. Written by Claude Code (AI-generated art; see assets/CREDITS.md).
shader_type sky;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec3 space_color : source_color = vec3(0.004, 0.006, 0.022);
uniform vec3 nebula_a : source_color = vec3(0.5, 0.1, 0.6);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.3, 0.65);
uniform float nebula_strength = 0.45;
// Stars sit in a grid of direction cells; more cells make them smaller and closer together.
uniform float star_cells = 220.0;
// Fraction of cells that hold a star.
uniform float star_chance = 0.012;
uniform vec3 planet_direction = vec3(0.3, -1.0, 0.25);
uniform float planet_radius_degrees = 42.0;
uniform vec3 planet_color : source_color = vec3(0.12, 0.38, 0.85);
uniform vec3 band_color : source_color = vec3(0.95, 0.72, 0.42);
uniform vec3 atmosphere_color : source_color = vec3(0.35, 0.65, 1.0);

vec3 stars(vec3 dir) {
	vec3 cell = floor(dir * star_cells);
	float h = hash31(cell);
	if (h > star_chance) {
		return vec3(0.0);
	}
	vec3 jitter = vec3(hash31(cell + 11.3), hash31(cell + 27.1), hash31(cell + 41.7)) - 0.5;
	vec3 star_dir = normalize((cell + 0.5 + jitter * 0.3) / star_cells);
	float spread = length(dir - star_dir) * star_cells; // In cells.
	float brightness = 1.0 - h / star_chance;
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), hash31(cell + 5.0));
	return tint * smoothstep(0.3, 0.0, spread) * (0.4 + 1.6 * brightness * brightness);
}

// The planet as a sphere at distance 1 along planet_direction: `covered` is 1 where it hides
// the sky. Returns its lit color there, or a thin atmosphere glow just outside its edge.
vec3 planet(vec3 dir, vec3 sun_dir, out float covered) {
	vec3 center = normalize(planet_direction);
	float radius = sin(radians(planet_radius_degrees));
	float along = dot(dir, center);
	float off_squared = 1.0 - along * along;
	float gap = radius * radius - off_squared;
	covered = 0.0;
	if (along <= 0.0) {
		return vec3(0.0);
	}
	if (gap <= 0.0) {
		float outside = sqrt(off_squared) - radius;
		return atmosphere_color * exp(-outside * 60.0) * 0.6;
	}
	covered = 1.0;
	float hit = along - sqrt(gap);
	vec3 normal = (dir * hit - center) / radius;
	float light = clamp(dot(normal, sun_dir), 0.0, 1.0);
	vec3 axis = normalize(vec3(0.2, 1.0, -0.3));
	float bands = sin(dot(normal, axis) * 18.0 + fbm3(normal * 4.0) * 3.0) * 0.5 + 0.5;
	vec3 surface = mix(planet_color, band_color, smoothstep(0.55, 0.9, bands) * 0.6);
	float rim = pow(1.0 - clamp(dot(normal, -dir), 0.0, 1.0), 3.0);
	return surface * (0.06 + 1.1 * light) + atmosphere_color * rim * (0.25 + light);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 color = space_color;
	color += nebula_a * smoothstep(0.5, 0.85, fbm3(dir * 2.5 + vec3(3.1, 0.0, 1.7))) * nebula_strength;
	color += nebula_b * smoothstep(0.55, 0.9, fbm3(dir * 3.5 + vec3(-5.2, 2.4, 0.3))) * nebula_strength;
	color += stars(dir);

	vec3 sun_dir = vec3(0.0, 1.0, 0.0);
	if (LIGHT0_ENABLED) {
		sun_dir = LIGHT0_DIRECTION;
		float facing = dot(dir, sun_dir);
		color += LIGHT0_COLOR * LIGHT0_ENERGY
				* (smoothstep(0.9997, 0.9999, facing) * 8.0 + pow(max(facing, 0.0), 300.0) * 0.5);
	}

	float covered;
	vec3 planet_color_here = planet(dir, sun_dir, covered);
	color = mix(color + planet_color_here, planet_color_here, covered);
	COLOR = color;
}
