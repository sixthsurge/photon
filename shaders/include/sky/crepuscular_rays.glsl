#if !defined INCLUDE_SKY_CREPUSCULAR_RAYS
#define INCLUDE_SKY_CREPUSCULAR_RAYS

#include "/include/misc/distant_horizons.glsl"
#include "/include/sky/clouds/common.glsl"
#include "/include/lighting/cloud_shadows.glsl"

vec4 draw_crepuscular_rays(
	sampler2D cloud_shadow_map,
	vec3 ray_direction_world, 
	bool is_terrain,
	float dither
) {
	const uint step_count_horizon = CREPUSCULAR_RAYS_STEPS_HORIZON;
	const uint step_count_zenith  = CREPUSCULAR_RAYS_STEPS_ZENITH;
	const float max_ray_length = 4096.0 / (CLOUDS_SCALE / 10.0);
#ifdef SKY_GROUND
	const float volume_inner_radius = planet_radius;
#else 
	// Allow volume to extend indefinitely into planet 
	const float volume_inner_radius = 1.0;
#endif
	const float volume_outer_radius = clouds_cumulus_radius + clouds_cumulus_thickness * 0.5;
	vec3 extinction_coeff = 2.0 * dampen(clouds_params.crepuscular_rays_amount) * (50.0 * air_rayleigh_coefficient + 400.0 * air_mie_coefficient) * (CLOUDS_SCALE / 10.0);

	const float underground_light_fade_distance = 100.0;

	uint step_count = uint(mix(
		step_count_horizon, 
		step_count_zenith, 
		dampen(abs(ray_direction_world.y))
	));

	// Calculate ray start and ray end

	float r = planet_radius + eyeAltitude * CLOUDS_SCALE;
	vec2 dists = intersect_spherical_shell(ray_direction_world.y, r, volume_inner_radius, volume_outer_radius) * rcp(CLOUDS_SCALE);
	bool planet_intersected = intersect_sphere(ray_direction_world.y, r, min(r - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0                                   // volume not intersected
	 //|| planet_intersected && r < clouds_cumulus_radius // planet blocking clouds
	 || is_terrain                             // terrain blocking clouds
	) { return vec4(vec3(0.0), 1.0); }

	float ray_length = clamp(dists.y - dists.x, 0.0, max_ray_length);
	float step_length = ray_length * rcp(float(step_count));

	// Transform to shadow view space

	vec3 ray_direction_shadow = mat3(shadowModelView) * ray_direction_world;
	vec3 ray_origin_shadow = shadowModelView[3].xyz + ray_direction_shadow * dists.x;
	vec3 ray_step_shadow = ray_direction_shadow * step_length;

	vec3 ray_origin_world = vec3(0.0, planet_radius, 0.0) + ray_direction_world * dists.x;
	vec3 ray_step_planet = ray_direction_world * step_length;

	// Raymarching loop

	vec3 scattering_coeff = extinction_coeff;
	vec3 step_optical_depth = extinction_coeff * step_length;
	vec3 step_transmittance = exp(-step_optical_depth);

	vec3 scattering = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (uint i = 0u; i < step_count; ++i) {
		vec3 ray_position_planet = ray_origin_world + ray_step_planet * (float(i) + dither);
		vec3 ray_position_shadow = ray_origin_shadow + ray_step_shadow * (float(i) + dither);

		float d = step_length * (float(i) + dither);

		float cloud_shadow = dot(texture(
			cloud_shadow_map, 
			shadow_view_to_cloud_shadow_space(ray_position_shadow)

			).xy, vec2(0.5));
		float a = linear_step(
			sqr(planet_radius - underground_light_fade_distance), 
			sqr(planet_radius), 
			length_squared(ray_position_planet)
		);
		float b = 1.0 - exp2(-0.002 * d);

		scattering += cube(cloud_shadow) * transmittance * a * b;
		transmittance *= step_transmittance;
	}

	// Lighting

	vec3 light_color = sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius);
	light_color = atmosphere_post_processing(light_color);
	light_color *= sunAngle > 0.5 ? moon_color : sun_color;

	float sunset_factor = pulse(light_dir.y, -0.01, 0.1);
	vec3 step_transmitted_fraction = (1.0 - step_transmittance) / max(step_optical_depth, eps);

	float LoV = dot(ray_direction_world, light_dir);

	float forwards = henyey_greenstein_phase(LoV, 0.5); 

	float phase = mix(0.5, 1.5, time_sunrise + time_sunset) * forwards // forwards lobe (max'ing them is completely nonsensical but it looks nice)
		+ 0.5 * henyey_greenstein_phase(LoV, -0.2); // backwards lobe

	scattering *= scattering_coeff * step_transmitted_fraction * light_color * step_length * clouds_params.crepuscular_rays_amount;
	scattering *= (6.0 * CREPUSCULAR_RAYS_INTENSITY) * phase;
	transmittance = mix(vec3(1.0), transmittance, clouds_params.crepuscular_rays_amount);

	return vec4(scattering, 1.0);
}

#endif // INCLUDE_SKY_CREPUSCULAR_RAYS
