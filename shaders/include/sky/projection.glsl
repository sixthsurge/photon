#if !defined INCLUDE_SKY_PROJECTION
#define INCLUDE_SKY_PROJECTION

#include "/include/utility/fast_math.glsl"

// Sky map projection from https://sebh.github.io/publications/egsr2020.pdf

const ivec2 sky_map_res = ivec2(191, 108);
const vec2  sky_map_pixel_size = rcp(vec2(sky_map_res));

vec2 project_sky(vec3 direction) {
	vec2 projected_dir = normalize(direction.xz);

	float azimuth_angle = pi + atan(projected_dir.x, -projected_dir.y);
	float altitude_angle = half_pi - fast_acos(direction.y);

	vec2 coord;
	coord.x = azimuth_angle * (1.0 / tau);
	coord.y = 0.5 + 0.5 * sign(altitude_angle) * sqrt(2.0 * rcp_pi * abs(altitude_angle)); // Section 5.3

	// Padding
	const float pad_amount = 2.0;
	const float mul = 1.0 - 2.0 * pad_amount * sky_map_pixel_size.x;
	const float add = pad_amount * sky_map_pixel_size.x;
	coord.x = coord.x * mul + add;

	coord.x *= 191.0 / 192.0;

	return coord;
}

vec3 unproject_sky(vec2 coord) {
	coord.x *= 192.0 / 191.0;

	// Padding
	const float pad_amount = 2.0;
	const float mul = rcp(1.0 - 2.0 * pad_amount * sky_map_pixel_size.x);
	const float add = (pad_amount * sky_map_pixel_size.x) * -mul;
	coord.x = fract(coord.x * mul + add);

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
