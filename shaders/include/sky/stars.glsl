#if !defined INCLUDE_SKY_STARS
#define INCLUDE_SKY_STARS

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstable_star_field(vec2 coord, float star_threshold) {
	const float min_temp = 4500.0;
	const float max_temp = 8500.0;

	vec4 noise = hash4(coord);

	float star = linear_step(star_threshold, 1.0, noise.x);
	      star = pow16(star) * STARS_INTENSITY;

	float temp = mix(min_temp, max_temp, noise.y);
	vec3 color = blackbody(temp);

	const float twinkle_speed = 2.0;
	float twinkle_amount = noise.z;
	float twinkle_offset = tau * noise.w;
	star *= 1.0 - twinkle_amount * cos(frameTimeCounter * twinkle_speed + twinkle_offset);

	return star * color;
}

// Stabilizes the star field by sampling at the four neighboring integer coordinates and
// interpolating
vec3 stable_star_field(vec2 coord, float star_threshold) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	f.x = cubic_smooth(f.x);
	f.y = cubic_smooth(f.y);

	return unstable_star_field(i + vec2(0.0, 0.0), star_threshold) * (1.0 - f.x) * (1.0 - f.y)
	     + unstable_star_field(i + vec2(1.0, 0.0), star_threshold) * f.x * (1.0 - f.y)
	     + unstable_star_field(i + vec2(0.0, 1.0), star_threshold) * f.y * (1.0 - f.x)
	     + unstable_star_field(i + vec2(1.0, 1.0), star_threshold) * f.x * f.y;
}

vec3 draw_stars(vec3 ray_dir, float galaxy_luminance) {
	// Adjust star threshold so that brightest stars appear first
#if defined WORLD_OVERWORLD
	float star_threshold = 1.0 - 0.05 * STARS_COVERAGE * smoothstep(-0.2, 0.05, -sun_dir.y) - 0.5 * cube(galaxy_luminance);
#else
	float star_threshold = 1.0 - 0.008 * STARS_COVERAGE;
#endif

	// Project ray direction onto the plane
	vec2 coord  = ray_dir.xy * rcp(abs(ray_dir.z) + length(ray_dir.xy)) + 41.21 * sign(ray_dir.z);
	     coord *= 600.0;

	return stable_star_field(coord, star_threshold);
}

#endif // INCLUDE_SKY_STARS
