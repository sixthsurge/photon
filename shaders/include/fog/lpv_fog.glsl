#if !defined INCLUDE_FOG_LPV_FOG
#define INCLUDE_FOG_LPV_FOG

#include "/include/lighting/lpv/blocklight.glsl"
#include "/include/utility/fast_math.glsl"

vec3 sample_lpv(vec3 position_world) {
	vec3 voxel_pos = scene_to_voxel_space(position_world - cameraPosition);
	vec3 sample_pos = voxel_pos / vec3(voxel_volume_size);

	if (clamp01(sample_pos) != sample_pos) {
		return vec3(0.0);
	}
	
	return read_lpv_linear(sample_pos);
}

#if defined WORLD_OVERWORLD 
vec2 overworld_fog_density_no_noise(vec3 position_world) {
	const vec2 mul = -rcp(air_fog_falloff_half_life);
	const vec2 add = -mul * air_fog_falloff_start;

	vec2 density = exp2(min(position_world.y * mul + add, 0.0));

	// fade away below sea level
	density *= linear_step(air_fog_volume_bottom, SEA_LEVEL, position_world.y);

	return density * (0.5 * OVERWORLD_FOG_INTENSITY);
}
#endif

mat2x3 get_lpv_fog_coefficients(vec3 position_world) {
	if (isEyeInWater == 1) {
		// Underwater

		const float density_mul = 8.0;
		const vec3 absorption_coeff = density_mul * vec3(WATER_ABSORPTION_R_UNDERWATER, WATER_ABSORPTION_G_UNDERWATER, WATER_ABSORPTION_B_UNDERWATER) * rec709_to_working_color;
		const vec3 scattering_coeff = density_mul * vec3(WATER_SCATTERING_UNDERWATER);
		const vec3 extinction_coeff = absorption_coeff + scattering_coeff;

		return mat2x3(scattering_coeff, extinction_coeff);
	}

#if defined WORLD_OVERWORLD
	// Scale applied to air fog coefficients
	const float overworld_density_scale = 8.0 * LPV_VL_INTENSITY_OVERWORLD;

	// Minimum overworld surface extinction and scattering - to prevent no glow when fog is very thin (high up)
	const vec3 overworld_fog_min_extinction = vec3(0.001);
	const vec3 overworld_fog_min_scattering = overworld_fog_min_extinction;

	// Overworld underground extinction and scattering
	const vec3 underground_fog_extinction = vec3(0.025) * LPV_VL_INTENSITY_UNDERGROUND;
	const vec3 underground_fog_scattering = underground_fog_extinction * 0.95;
	const float underground_fog_fade_length = 20.0;

	vec2 density = overworld_fog_density_no_noise(position_world);

	vec3 scattering = fog_params.rayleigh_scattering_coeff * density.x 
		+ fog_params.mie_scattering_coeff * density.y;

	vec3 extinction = fog_params.rayleigh_scattering_coeff * density.x 
		+ fog_params.mie_extinction_coeff * density.y;

	float underground_factor = linear_step(
		SEA_LEVEL,
		SEA_LEVEL - underground_fog_fade_length, 
		position_world.y
	);
	scattering = mix(
		max(scattering, overworld_fog_min_scattering) * overworld_density_scale, 
		underground_fog_scattering,
		underground_factor
	);
	extinction = mix(
		max(extinction, overworld_fog_min_extinction) * overworld_density_scale, 
		underground_fog_extinction,
		underground_factor
	);

	return mat2x3(scattering, extinction);
#elif defined WORLD_NETHER
	float density = 0.05 * LPV_VL_INTENSITY_NETHER;
	return mat2x3(vec3(density), density * (exp2(-4.0 * ambient_color)));
#elif defined WORLD_END 
	float density = 0.06 * LPV_VL_INTENSITY_END;
	return mat2x3(vec3(density), density * (exp2(-4.0 * ambient_color)));
#endif
}

vec3 get_lpv_fog_scattering(
	vec3 ray_origin_world,
	vec3 ray_end_world,
	float dither
) {
	const uint step_count      = LPV_VL_STEPS;
	const float step_ratio     = 1.1;

	vec3 ray_direction_world; float ray_length;
	length_normalize(ray_end_world - ray_origin_world, ray_direction_world, ray_length);

	// Clip ray length to voxel volume
	vec3 origin_to_center = get_voxel_volume_center(gbufferModelViewInverse[2].xyz);
	float distance_center_to_edge = 0.5 * float(VOXEL_VOLUME_SIZE) * rcp(max_of(abs(ray_direction_world)));
	ray_length = min(
		ray_length, 
		length(-origin_to_center + ray_direction_world * distance_center_to_edge)
	);

	// Geometric sample distribution
	const float initial_step_scale = step_ratio == 1.0 
		? rcp(float(step_count)) 
		: (step_ratio - 1.0) / (pow(step_ratio, float(step_count)) - 1.0);
	float step_length = ray_length * initial_step_scale;

	vec3 ray_position_world = ray_origin_world;

	vec3 inscattered_light = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (uint i = 0u; i < step_count; ++i) { 
		vec3 dithered_position_world = ray_position_world + ray_direction_world * (dither * step_length);
		
		// Greater density further from the camera
		float distance_factor = 0.1 + 0.9 * clamp01(
			length_squared(dithered_position_world - cameraPosition) * rcp(32.0 * 32.0)
		);

		vec3 light = sqrt(sample_lpv(dithered_position_world));
		light *= sqrt(sqrt(light));
		mat2x3 coefficients = get_lpv_fog_coefficients(dithered_position_world) * step_length * distance_factor; // scattering, extinction

		vec3 step_transmittance = exp(-coefficients[1]);
		vec3 step_transmitted_fraction = (1.0 - step_transmittance) / max(coefficients[1], eps);

		vec3 visible_scattering = step_transmitted_fraction * transmittance;

		inscattered_light += light * visible_scattering * coefficients[0];
		transmittance *= step_transmittance;

		ray_position_world += ray_direction_world * step_length;
		step_length *= step_ratio;
	
	}

	return inscattered_light * isotropic_phase * clamp01(1.0 - blindness - darknessFactor);
}

#endif // INCLUDE_FOG_LPV_FOG
