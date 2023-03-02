#ifndef INCLUDE_SKY_PROJECTION
#define INCLUDE_SKY_PROJECTION

#include "/include/utility/fast_math.glsl"

// Sky map projection from https://sebh.github.io/publications/egsr2020.pdf

const ivec2 sky_map_res = ivec2(192, 108);

vec2 project_sky(vec3 direction) {
	vec2 projected_dir = normalize(direction.xz);

	float azimuth_angle = pi + atan(projected_dir.x, -projected_dir.y);
	float altitude_angle = half_pi - fast_acos(direction.y);

	vec2 coord;
	coord.x = azimuth_angle * (1.0 / tau);
	coord.y = 0.5 + 0.5 * sign(altitude_angle) * sqrt(2.0 * rcp_pi * abs(altitude_angle)); // Section 5.3

	return vec2(
		get_uv_from_unit_range(coord.x, sky_map_res.x),
		get_uv_from_unit_range(coord.y, sky_map_res.y)
	);
}

vec3 unproject_sky(vec2 coord) {
	coord = vec2(
		get_unit_range_from_uv(coord.x, sky_map_res.x),
		get_unit_range_from_uv(coord.y, sky_map_res.y)
	);

	// Non-linear mapping of altitude angle (See section 5.3 of the paper)
	coord.y = (coord.y < 0.5)
		? -sqr(1.0 - 2.0 * coord.y)
		:  sqr(2.0 * coord.y - 1.0);

	float azimuth_angle = coord.x * tau - pi;
	float altitude_angle = coord.y * half_pi;

	float altitude_cos = cos(altitude_angle);
	float altitude_sin = sin(altitude_angle);
	float azimuth_cos = cos(azimuth_angle);
	float azimuth_sin = sin(azimuth_angle);

	return vec3(altitude_cos * azimuth_sin, altitude_sin, -altitude_cos * azimuth_cos);
}

#endif // INCLUDE_SKY_PROJECTION
