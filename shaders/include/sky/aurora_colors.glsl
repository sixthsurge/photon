#if !defined INCLUDE_SKY_AURORA_COLORS
#define INCLUDE_SKY_AURORA_COLORS

#include "/include/utility/random.glsl"

// [0] - bottom color
// [1] - top color
mat2x3 get_aurora_colors() {
	const mat2x3[] aurora_colors = mat2x3[](
		mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.00, 0.00), // red
			vec3(1.00, 0.50, 0.70)  // purple
		)
		, mat2x3(
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.25, 0.25, 1.00)  // deep blue
		)
		, mat2x3(
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.10, 0.00), // red
			vec3(1.00, 1.00, 0.25)  // yellow
		)
		, mat2x3(
			vec3(1.00, 1.00, 1.00), // white
			vec3(1.00, 0.00, 0.00)  // red
		)
		, mat2x3(
			vec3(1.00, 1.00, 0.00), // yellow
			vec3(0.10, 0.50, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.00, 1.00, 0.25)  // green
		)
		, mat2x3(
			vec3(1.00, 0.70, 1.00) * 1.2, // pink
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3(
			vec3(2.00, 0.80, 0.00), // orange
			vec3(1.00, 0.50, 0.00)  // orange
		)
	);

	uint day_index = uint(worldDay);
	     day_index = lowbias32(day_index) % aurora_colors.length();

	return aurora_colors[day_index];
}

// 0.0 - no aurora
// 1.0 - full aurora
float get_aurora_amount() {
	float night = smoothstep(0.0, 0.2, -sun_dir.y);

#if   AURORA_NORMAL == AURORA_NEVER
	float aurora_normal = 0.0;
#elif AURORA_NORMAL == AURORA_RARELY
	float aurora_normal = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_NORMAL == AURORA_ALWAYS
	float aurora_normal = 1.0;
#endif

#if   AURORA_SNOW == AURORA_NEVER
	float aurora_snow = 0.0;
#elif AURORA_SNOW == AURORA_RARELY
	float aurora_snow = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_SNOW == AURORA_ALWAYS
	float aurora_snow = 1.0;
#endif

	return night * mix(aurora_normal, aurora_snow, biome_may_snow);
}

#endif // INCLUDE_SKY_AURORA_COLORS
