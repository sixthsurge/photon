#if !defined INCLUDE_SKY_CLOUDS_CUMULUS
#define INCLUDE_SKY_CLOUDS_CUMULUS

// 1st layer: volumetric cumulus/stratocumulus/stratus clouds

#include "common.glsl"
#include "coverage_map.glsl"

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float clouds_cumulus_altitude_shaping(float density, float altitude_fraction) {
	// Stratus shapes
	if (clouds_params.l0_cumulus_stratus_blend > eps) {
		density = mix(
			density, 
			clamp01(
				density * dampen(clamp01(2.0 * altitude_fraction) 
					* linear_step(0.0, 0.1, altitude_fraction) 
					* linear_step(0.0, 0.6, 1.0 - altitude_fraction))
			),
			clouds_params.l0_cumulus_stratus_blend
		);
	}

	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) 
		* (0.6 - 0.3 * clouds_params.l0_cumulus_stratus_blend);

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_cumulus_density(vec3 pos) {
	float r = length(pos);

#if defined CLOUDS_USE_LOCAL_COVERAGE_MAP
	// Get local coverage from precomputed coverage map - saves 1 sample and some maths
	vec2 coverage_map_uv = project_clouds_cumulus_coverage_map(pos);

	if (
		r < clouds_cumulus_radius || r > clouds_cumulus_top_radius 
			|| clamp01(coverage_map_uv) != coverage_map_uv
	) {
		return 0.0;
	}

	float density = texture(colortex8, coverage_map_uv).z;
#else 
	if (r < clouds_cumulus_radius || r > clouds_cumulus_top_radius) {
		return 0.0;
	}

	float density = clouds_cumulus_local_coverage(pos.xz);
#endif

	// Altitude shaping 

	float altitude_fraction = (r - clouds_cumulus_radius) * clouds_params.l0_altitude_scale;

	density = clouds_cumulus_altitude_shaping(
		density,
		altitude_fraction
	);

	if (density < eps) return 0.0;

#if !defined PROGRAM_PREPARE
	const float wind_angle = CLOUDS_CUMULUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CUMULUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	pos.xz += cameraPosition.xz * CLOUDS_SCALE + wind.xz;

	// 3D worley noise for detail
	float worley_0 = texture(SAMPLER_WORLEY_BUBBLY, (pos + 0.2 * wind) * 0.0009).x;
	float worley_1 = texture(SAMPLER_WORLEY_SWIRLEY, (pos + 0.4 * wind) * 0.005).x;
#else
	const float worley_0 = 0.5;
	const float worley_1 = 0.5;
#endif

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.6;

	density -= clouds_params.l0_detail_weights.x * sqr(worley_0) * dampen(clamp01(1.0 - density));
	density -= clouds_params.l0_detail_weights.y * sqr(worley_1) * dampen(clamp01(1.0 - density)) * detail_fade;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density = max0(density);
	density = lift(
		density,
		mix(
			clouds_params.l0_edge_sharpening.x, 
			clouds_params.l0_edge_sharpening.y, 
			altitude_fraction
		)
	);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_cumulus_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 0.1 * clouds_cumulus_thickness / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_cumulus_density(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_cumulus_scattering(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = clouds_params.l0_scattering_coeff;
	float extinct_amount = clouds_params.l0_extinction_coeff;

	float scattering_integral_times_density = (1.0 - step_transmittance) / clouds_params.l0_extinction_coeff;

	float powder_effect = clouds_powder_effect(density + density * clouds_params.l0_cumulus_stratus_blend, cos_theta);
	float scattering_falloff = 0.55 * mix(lift(clamp01(clouds_params.l0_scattering_coeff / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase * (1.0 - 0.5 * clouds_params.l0_shadow);
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.x += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase * clouds_params.l0_shadow * 0.5; // fake bounced lighting from the layer above
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= scattering_falloff * powder_effect;
		extinct_amount *= 0.4;
		phase_g *= 0.8;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density;
}

CloudsResult draw_cumulus_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

#if defined PROGRAM_DEFERRED0
	const uint  primary_steps_horizon = CLOUDS_CUMULUS_PRIMARY_STEPS_H / 2;
	const uint  primary_steps_zenith  = CLOUDS_CUMULUS_PRIMARY_STEPS_Z / 2;
#else
	const uint  primary_steps_horizon = CLOUDS_CUMULUS_PRIMARY_STEPS_H;
	const uint  primary_steps_zenith  = CLOUDS_CUMULUS_PRIMARY_STEPS_Z;
#endif
	const uint  lighting_steps        = CLOUDS_CUMULUS_LIGHTING_STEPS;
	const uint  ambient_steps         = CLOUDS_CUMULUS_AMBIENT_STEPS;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const float planet_albedo         = 0.4;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	// Early exit if coverage is 0
	if (clouds_params.l0_coverage.y < eps) { return clouds_not_hit; }

	uint primary_steps = uint(mix(
		primary_steps_horizon, 
		primary_steps_zenith, 
		abs(ray_dir.y)
	));

	float r = length(air_viewer_pos);

	vec2 dists = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_cumulus_radius, clouds_cumulus_top_radius);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;
	bool terrain_intersected = distance_to_terrain >= 0.0 && r < clouds_cumulus_radius && distance_to_terrain < dists.x;

	if (dists.y < 0.0                                   // volume not intersected
	 || planet_intersected && r < clouds_cumulus_radius // planet blocking clouds
	 || terrain_intersected                             // terrain blocking clouds
	) { return clouds_not_hit; }

	float ray_length = (distance_to_terrain >= 0.0) ? distance_to_terrain : dists.y;
	      ray_length = clamp(ray_length - dists.x, 0.0, max_ray_length);
	float step_length = ray_length * rcp(float(primary_steps));

	vec3 ray_step = ray_dir * step_length;
	vec3 ray_origin = air_viewer_pos + ray_dir * (dists.x + step_length * dither);

	vec2 scattering = vec2(0.0); // x: direct light, y: skylight
	float transmittance = 1.0;

	float distance_sum = 0.0;
	float distance_weight_sum = 0.0;

	// ------------------
	//   Lighting Setup
	// ------------------

	bool  moonlit            = sun_dir.y < -0.04;
	vec3  light_dir          = moonlit ? moon_dir : sun_dir;
	float cos_theta          = dot(ray_dir, light_dir);
	float bounced_light      = planet_albedo * light_dir.y * rcp_pi;

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i) {
		if (transmittance < min_transmittance) break;

		vec3 ray_pos = ray_origin + ray_step * i;

		float altitude_fraction = (length(ray_pos) - clouds_cumulus_radius) * rcp(clouds_cumulus_thickness);

		float density = clouds_cumulus_density(ray_pos); 

		if (density < eps) continue;

		// Fade away in the distance to hide the max ray length cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		density *= smoothstep(1.0, 0.95, distance_to_sample * rcp(max_ray_length));

#if defined CLOUDS_USE_LOCAL_COVERAGE_MAP
		// Fade away at the edges of the local coverage map
		density *= smoothstep(1.0, 0.9, length(ray_pos.xz) * rcp(0.5 * clouds_cumulus_coverage_map_scale));
#endif

		float step_optical_depth = density * clouds_params.l0_extinction_coeff * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_cumulus_optical_depth(ray_pos, light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_cumulus_optical_depth(ray_pos, sky_dir, hash.y, ambient_steps);
		// guess optical depth to the ground using altitude fraction and density from this sample
		float ground_optical_depth = mix(
			density, 
			1.0, 
			clamp01(altitude_fraction * 2.0 - 1.0)
		) * altitude_fraction * clouds_cumulus_thickness; 

		scattering += clouds_cumulus_scattering(
			density,
			light_optical_depth,
			sky_optical_depth,
			ground_optical_depth,
			step_transmittance,
			cos_theta,
			bounced_light
		) * transmittance;

		transmittance *= step_transmittance;

		// Update distance to cloud
		distance_sum += distance_to_sample * density;
		distance_weight_sum += density;
	}

	// Get main light color for this layer
	vec3 light_color  = sunlight_color * atmosphere_transmittance(ray_origin, light_dir);
		 light_color  = atmosphere_post_processing(light_color);
	     light_color *= moonlit ? moon_color : sun_color;

	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	float apparent_distance = (distance_weight_sum == 0.0)
		? 1e6
		: (distance_sum / distance_weight_sum) + distance(air_viewer_pos, ray_origin);

	return CloudsResult(
		vec4(clouds_scattering, scattering.y),
		clouds_transmittance,
		apparent_distance
	);
}

#endif
