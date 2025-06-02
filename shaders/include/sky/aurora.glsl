#if !defined INCLUDE_SKY_AURORA
#define INCLUDE_SKY_AURORA

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"

float aurora_shape(vec3 pos, float altitude_fraction) {
	const vec2 wind_0     = 0.005 * vec2(0.7, 0.1);
	const vec2 wind_1     = 0.008 * vec2(-0.1, -0.7);
	const float frequency = 0.00003 * AURORA_FREQUENCY;

	float height_fade = cube(1.0 - altitude_fraction) * linear_step(0.0, 0.025, altitude_fraction);

	float worley_0 = texture(noisetex, pos.xz * frequency + wind_0 * frameTimeCounter).y;
	float worley_1 = texture(noisetex, pos.xz * frequency + wind_1 * frameTimeCounter).y;

	return linear_step(1.0, 2.0, worley_0 + worley_1) * height_fade;
}

vec3 aurora_color(vec3 pos, float altitude_fraction) {
	return mix(aurora_colors[0], aurora_colors[1], clamp01(dampen(altitude_fraction))); 
}

vec3 draw_aurora(vec3 ray_dir, float dither) {
	const uint step_count      = 64u;
	const float rcp_steps      = rcp(float(step_count));
	const float volume_bottom  = 1000.0;
	const float volume_top     = 3000.0;
	const float volume_radius  = 20000.0;

	if (aurora_amount < 0.01) return vec3(0.0);

	// Calculate distance to enter and exit the volume

	float rcp_dir_y = rcp(ray_dir.y);
	float distance_to_lower_plane = volume_bottom * rcp_dir_y;
	float distance_to_upper_plane = volume_top    * rcp_dir_y;
	float distance_to_cylinder    = volume_radius * rcp_length(ray_dir.xz);

	float distance_to_volume_start = distance_to_lower_plane;
	float distance_to_volume_end   = min(distance_to_cylinder, distance_to_upper_plane);

	// Make sure that the volume is intersected
	if (distance_to_volume_start > distance_to_volume_end) return vec3(0.0);

	// Raymarching setup

	float ray_length  = max0(distance_to_volume_end - distance_to_volume_start);
	float step_length = ray_length * rcp_steps;

	vec3 ray_pos  = ray_dir * (distance_to_volume_start + step_length * dither);
	vec3 ray_step = ray_dir * step_length;

	vec3 emission = vec3(0.0);

	// Raymarching loop

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step) {
		float altitude_fraction = linear_step(volume_bottom, volume_top, ray_pos.y);
		float shape = aurora_shape(ray_pos, altitude_fraction);
		vec3 color  = aurora_color(ray_pos, altitude_fraction);

		float d = length(ray_pos.xz);
		float distance_fade = (1.0 - cube(d * rcp(volume_radius))) * (1.0 - exp2(-0.001 * d));

		emission += color * (shape * distance_fade * step_length);
	}

	return (0.001 * AURORA_BRIGHTNESS) * emission * aurora_amount;
}

#endif // INCLUDE_SKY_AURORA
