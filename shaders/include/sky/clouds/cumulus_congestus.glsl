#if !defined INCLUDe_SKY_CLOUDS_CUMULUS_CONGESTUS
#define INCLUDE_SKY_CLOUDS_CUMULUS_CONGESTUS

// Alternative 1st layer: distant cumulus congestus clouds

#include "common.glsl"

const float clouds_cumulus_congestus_radius           = planet_radius + CLOUDS_CUMULUS_CONGESTUS_ALTITUDE;
const float clouds_cumulus_congestus_thickness        = CLOUDS_CUMULUS_CONGESTUS_ALTITUDE * CLOUDS_CUMULUS_CONGESTUS_THICKNESS;
const float clouds_cumulus_congestus_top_radius       = clouds_cumulus_congestus_radius + clouds_cumulus_congestus_thickness;
const float clouds_cumulus_congestus_distance         = 30000.0;
const float clouds_cumulus_congestus_end_distance     = 50000.0;
float clouds_cumulus_congestus_extinction_coeff       = 0.08;
float clouds_cumulus_congestus_scattering_coeff       = clouds_cumulus_congestus_extinction_coeff * (1.0 - 0.2 * rainStrength);

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float clouds_cumulus_congestus_altitude_shaping(float density, float altitude_fraction) {
	// Carve egg shape
	density -= sqr(linear_step(0.3, 1.0, altitude_fraction)) * clamp01(1.0 - 0.2 * clouds_params.cumulus_congestus_blend);

	// Reduce density at the top and bottom of the cloud
	density *= smoothstep(0.0, 0.1, altitude_fraction);
	density *= smoothstep(0.0, 0.1, 1.0 - altitude_fraction);

	return density;
}

float clouds_cumulus_congestus_density(vec3 pos) {
	const float wind_angle = CLOUDS_CUMULUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CUMULUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_cumulus_congestus_radius || r > clouds_cumulus_congestus_top_radius) return 0.0;

	float altitude_fraction = (r - clouds_cumulus_congestus_radius) * rcp(clouds_cumulus_congestus_thickness);
	float distance_fraction = linear_step(clouds_cumulus_congestus_distance, clouds_cumulus_congestus_end_distance, length(pos.xz));

	pos.xz += cameraPosition.xz * CLOUDS_SCALE;

	// 2D noise for base shape and coverage
	float noise = texture(noisetex, (0.000003 / CLOUDS_CUMULUS_CONGESTUS_SIZE) * (pos.xz + wind_velocity * (world_age + 50.0 * sqr(altitude_fraction)))).w;

	float density  = 1.5 * sqr(linear_step(0.75 - 0.15 * clamp01(clouds_params.cumulus_congestus_blend * CLOUDS_CUMULUS_CONGESTUS_COVERAGE), 1.0, sqrt(noise)));
	      density  = clouds_cumulus_congestus_altitude_shaping(density, altitude_fraction);
		  density *= 4.0 * distance_fraction * (1.0 - distance_fraction);
		  density *= linear_step(0.0, 0.3, clouds_params.cumulus_congestus_blend);

	if (density < eps) return 0.0;

#ifndef PROGRAM_PREPARE
	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley_0 = texture(SAMPLER_WORLEY_SWIRLEY, (pos + 0.2 * wind) * 0.00005).x;
	float worley_1 = texture(SAMPLER_WORLEY_SWIRLEY, (pos + 0.4 * wind) * 0.00023).x;
#else
	const float worley_0 = 0.5;

	const float worley_1 = 0.5;
#endif

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.8;

	density -= (7.0 * CLOUDS_CUMULUS_CONGESTUS_DETAIL_STRENGTH) * sqr(clamp01(1.0 - density)) * cube(worley_0) * sqr(altitude_fraction);
	density -= (0.2 * CLOUDS_CUMULUS_CONGESTUS_DETAIL_STRENGTH) * sqr(worley_1) * dampen(clamp01(1.0 - density)) * dampen(dampen(clamp01(detail_fade + 0.5 * sqr(altitude_fraction))));

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = lift(clamp01(density), mix(2.0, 10.0, altitude_fraction));
	density *= sqr(linear_step(0.0, 0.5, altitude_fraction));

	return density;
}

float clouds_cumulus_congestus_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 0.1 * clouds_cumulus_congestus_thickness / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_cumulus_congestus_density(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_cumulus_congestus_scattering(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = clouds_cumulus_congestus_scattering_coeff;
	float extinct_amount = clouds_cumulus_congestus_extinction_coeff;

	float scattering_integral_times_density = (1.0 - step_transmittance) / clouds_cumulus_congestus_extinction_coeff;

	float powder_effect = clouds_powder_effect(2.0 * density, cos_theta);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth * 0.33) * phase;
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth * 0.33) * isotropic_phase * bounced_light;
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth * 0.33) * isotropic_phase;

		scatter_amount *= 0.55 * mix(lift(clamp01(clouds_cumulus_congestus_scattering_coeff / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5) * powder_effect;
		extinct_amount *= 0.4;
		phase_g *= 0.5;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density;
}

CloudsResult draw_cumulus_congestus_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

	const uint  primary_steps     = CLOUDS_CUMULUS_CONGESTUS_PRIMARY_STEPS;
	const uint  lighting_steps    = CLOUDS_CUMULUS_CONGESTUS_LIGHTING_STEPS;
	const uint  ambient_steps     = CLOUDS_CUMULUS_CONGESTUS_AMBIENT_STEPS;

	const float min_transmittance = 0.075;

	const float planet_albedo     = 0.4;
	const vec3  sky_dir           = vec3(0.0, 1.0, 0.0);

	vec2 sphere_dists   = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_cumulus_congestus_radius, clouds_cumulus_congestus_top_radius);
	vec2 cylinder_dists = intersect_cylindrical_shell(air_viewer_pos, ray_dir, clouds_cumulus_congestus_distance, clouds_cumulus_congestus_end_distance);
	vec2 dists          = vec2(max(sphere_dists.x, cylinder_dists.x), min(sphere_dists.y, cylinder_dists.y));

	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(length(air_viewer_pos) - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0
	 || planet_intersected && length(air_viewer_pos) < clouds_cumulus_congestus_radius
	 || distance_to_terrain > 0.0
	) { return clouds_not_hit; }

	float ray_length = dists.y - dists.x;
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

	bool moonlit = sun_dir.y < -0.04;
	vec3 light_dir = moonlit ? moon_dir : sun_dir;
	float cos_theta = dot(ray_dir, light_dir);
	float bounced_light = planet_albedo * light_dir.y * rcp_pi;

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i) {
		if (transmittance < min_transmittance) break;

		vec3 ray_pos = ray_origin + ray_step * i;

		float altitude_fraction = (length(ray_pos) - clouds_cumulus_congestus_radius) * rcp(clouds_cumulus_congestus_thickness);

		float density = clouds_cumulus_congestus_density(ray_pos);

		if (density < eps) continue;

		float distance_to_sample = distance(ray_origin, ray_pos);

		float step_optical_depth = density * clouds_cumulus_congestus_extinction_coeff * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_cumulus_congestus_optical_depth(ray_pos, light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_cumulus_congestus_optical_depth(ray_pos, sky_dir, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_cumulus_congestus_thickness; // guess optical depth to the ground using altitude fraction and density from this sample

		scattering += clouds_cumulus_congestus_scattering(
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

	// Aerial perspective
	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	// Fade away at the horizon
	float horizon_fade = mix(dampen(linear_step(0.0, 0.08, ray_dir.y)), 1.0, smoothstep(sqr(clouds_cumulus_congestus_radius), sqr(clouds_cumulus_congestus_radius + 0.1 * clouds_cumulus_congestus_thickness), length_squared(air_viewer_pos)));
	clouds_scattering = mix(clear_sky * (1.0 - clouds_transmittance), clouds_scattering, horizon_fade);

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
