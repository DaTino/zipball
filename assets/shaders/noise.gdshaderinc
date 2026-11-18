// Small value-noise helpers shared by the venue shaders.
// Written by Claude Code (AI-generated art; see assets/CREDITS.md).

// The hashes below give a random value from 0 to 1 for the grid cell holding `p` (the point
// is rounded down to whole numbers first). They work in integers, so they are exact: every
// noise cell that shares a corner computes the same value for it. A float-only hash amplifies
// rounding, so the GPU can round a shared corner differently in neighboring cells, and that
// showed as straight seams along the noise grid on the Desert floor.

// Scrambles the bits of a 32-bit number ("lowbias32" mixer).
uint mix_bits(uint h) {
	h ^= h >> 16u;
	h *= 2146121005u;
	h ^= h >> 15u;
	h *= 2221713035u;
	h ^= h >> 16u;
	return h;
}

// 24 bits of `h` as a float from 0 to just under 1.
float unit_float(uint h) {
	return float(h >> 8u) * (1.0 / 16777216.0);
}

uint hash_cell2(vec2 p) {
	ivec2 q = ivec2(floor(p));
	return mix_bits(uint(q.x) * 73856093u ^ mix_bits(uint(q.y) + 19349663u));
}

float hash21(vec2 p) {
	return unit_float(hash_cell2(p));
}

vec2 hash22(vec2 p) {
	uint h = hash_cell2(p);
	return vec2(unit_float(h), unit_float(mix_bits(h + 83492791u)));
}

float hash31(vec3 p) {
	ivec3 q = ivec3(floor(p));
	return unit_float(mix_bits(uint(q.x) * 73856093u ^ mix_bits(uint(q.y) * 19349663u ^ mix_bits(uint(q.z) + 83492791u))));
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x),
				mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x),
				mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
			f.z);
}

float fbm2(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amplitude * noise2(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return sum;
}

float fbm3(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amplitude * noise3(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return sum;
}

// How far `distance` meters of air hides things: 0 = clear, 1 = all haze.
float haze_amount(float distance, float density) {
	return 1.0 - exp(-distance * density);
}
