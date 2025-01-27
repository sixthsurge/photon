#if !defined INCLUDE_FOG_LPV_FOG
#define INCLUDE_FOG_LPV_FOG

#include "/include/utility/fast_math.glsl"

mat2x3 get_lpv_fog_coefficients(vec3 position_world) {
#if defined WORLD_OVERWORLD
	vec2 densities = air_fog_density(position_world);

	return mat2x3(
		air_fog_coeff[0][0] * densities.x + air_fog_coeff[1][0] * densities.y,
		air_fog_coeff[1][0] * densities.x + air_fog_coeff[1][1] * densities.y
	);
#else 
	return vec3(1e-3);
#endif
}

vec3 get_lpv_fog_contribution(
	vec3 ray_origin_world,
	vec3 ray_end_world,
	float dither
) {
	const uint step_count      = 8u;
	const float step_ratio     = 1.5;
	const float max_ray_length = 4096.0;

	vec3 ray_direction_world; float ray_length;
	length_normalize(ray_end_world - ray_origin_world, ray_direction_world, ray_length);
	ray_length = min(ray_length, max_ray_length);

	// geometric sample distribution
	const float initial_step_scale = (step_ratio - 1.0) / (pow(step_ratio, float(step_count)) - 1.0);
	float step_length = ray_length * initial_step_scale;

	vec3 ray_position_world = ray_origin_world;

	vec3 inscattered_light = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (uint i = 0u; i < step_count; ++i) { 
		vec3 dithered_position_world = ray_position_world + ray_direction_world * (dither * step_length);

		vec3 light = sample_lpv();
		mat2x3 coefficients = get_lpv_fog_coefficients(dithered_position_world);

		ray_position_world += ray_direction_world * step_length;
		step_length *= step_ratio;
	}

	return inscattered_light;
}

#endif // INCLUDE_FOG_LPV_FOG
