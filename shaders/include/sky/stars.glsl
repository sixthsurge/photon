#if !defined INCLUDE_SKY_STARS
#define INCLUDE_SKY_STARS

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstable_star_field(vec2 coord, vec2 local_f, float star_threshold) {
	const float min_temp = 4500.0;
	const float max_temp = 8500.0;

	vec4 noise = hash4(coord);

	float base = linear_step(star_threshold, 1.0, noise.x);
	base = pow16(base) * STARS_INTENSITY;

	float temp = mix(min_temp, max_temp, noise.y);
	vec3 color = blackbody(temp);

#ifdef TWINKLE_ENABLED
	const float twinkle_speed = TWINKLE_SPEED * 2.0;
	float twinkle_amount = noise.z;
	float twinkle_offset = tau * noise.w;
	base *= 1.0 - twinkle_amount * cos(frameTimeCounter * twinkle_speed + twinkle_offset);
#endif

	vec2 center_offset = (noise.zw - 0.5) * 0.8;
	float star_size = mix(0.25, 1.6, noise.x);

	vec2 rel = local_f - 0.5 - center_offset;
	float r2 = dot(rel, rel);

	float disk = exp(-r2 * (40.0 / (star_size * star_size)));
	float halo = exp(-r2 * (8.0  / (star_size * star_size))) * 0.15;

	float shape = clamp(disk + halo, 0.0, 1.0);

	float star = base * shape;

	return star * color;
}

vec3 stable_star_field(vec2 coord, float star_threshold) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	vec2 fs = vec2(cubic_smooth(f.x), cubic_smooth(f.y));

	vec2 f00 = f - vec2(0.0, 0.0);
	vec2 f10 = f - vec2(1.0, 0.0);
	vec2 f01 = f - vec2(0.0, 1.0);
	vec2 f11 = f - vec2(1.0, 1.0);

	float w00 = (1.0 - fs.x) * (1.0 - fs.y);
	float w10 = (    fs.x) * (1.0 - fs.y);
	float w01 = (1.0 - fs.x) * (    fs.y);
	float w11 = (    fs.x) * (    fs.y);

	return unstable_star_field(i + vec2(0.0, 0.0), f00, star_threshold) * w00
		 + unstable_star_field(i + vec2(1.0, 0.0), f10, star_threshold) * w10
		 + unstable_star_field(i + vec2(0.0, 1.0), f01, star_threshold) * w01
		 + unstable_star_field(i + vec2(1.0, 1.0), f11, star_threshold) * w11;
}

vec3 draw_stars(vec3 ray_dir, float galaxy_luminance) {
#if defined WORLD_OVERWORLD
	float star_threshold = 1.0 - 0.05 * STARS_COVERAGE * smoothstep(-0.2, 0.05, -sun_dir.y) - 0.5 * cube(galaxy_luminance);
#else
	float star_threshold = 1.0 - 0.008 * STARS_COVERAGE;
#endif

	vec2 coord  = ray_dir.xy * rcp(abs(ray_dir.z) + length(ray_dir.xy)) + 41.21 * sign(ray_dir.z);
	     coord *= 600.0;

	return stable_star_field(coord, star_threshold);
}

#endif // INCLUDE_SKY_STARS