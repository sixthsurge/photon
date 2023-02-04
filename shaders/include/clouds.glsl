#if !defined CLOUDS_INCLUDED
#define CLOUDS_INCLUDED

#include "/include/atmosphere.glsl"
#include "/include/phase_functions.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

float clouds_phase_single(float cos_theta) { // Single scattering phase function
	return 0.8 * klein_nishina_phase(cos_theta, 2600.0)    // forwards lobe
	     + 0.2 * henyey_greenstein_phase(cos_theta, -0.2); // backwards lobe
}

float clouds_phase_multi(float cos_theta, vec3 g) { // Multiple scattering phase function
	return 0.65 * henyey_greenstein_phase(cos_theta,  g.x)  // forwards lobe
	     + 0.10 * henyey_greenstein_phase(cos_theta,  g.y)  // forwards peak
	     + 0.25 * henyey_greenstein_phase(cos_theta, -g.z); // backwards lobe
}

float clouds_powder_effect(float density, float cos_theta) {
	float powder = pi * density / (density + 0.15);
	      powder = mix(powder, 1.0, 0.8 * sqr(cos_theta * 0.5 + 0.5));

	return powder;
}

vec3 clouds_aerial_perspective(
	vec3 clouds_scattering,
	float clouds_transmittance,
	vec3 ray_origin,
	vec3 ray_end,
	vec3 ray_dir,
	vec3 clear_sky
) {
	vec3 air_transmittance;

	if (length_squared(ray_origin) < length_squared(ray_end)) {
		vec3 trans_0 = atmosphere_transmittance(ray_origin, ray_dir);
		vec3 trans_1 = atmosphere_transmittance(ray_end,    ray_dir);

		air_transmittance = clamp01(trans_0 / trans_1);
	} else {
		vec3 trans_0 = atmosphere_transmittance(ray_origin, -ray_dir);
		vec3 trans_1 = atmosphere_transmittance(ray_end,    -ray_dir);

		air_transmittance = clamp01(trans_1 / trans_0);
	}

	clear_sky = mix(clear_sky, sky_color * rcp(tau), rainStrength * mix(1.0, 0.9, time_sunrise + time_sunset));
	air_transmittance = mix(air_transmittance, vec3(air_transmittance.x), 0.8 * rainStrength);

	return mix((1.0 - clouds_transmittance) * clear_sky, clouds_scattering, air_transmittance);
}

/*
--------------------------------------------------------------------------------

  1st layer: cumulus/stratocumulus clouds

  altitude: 1200-2400m
  description: low-level, cauliflower-shaped clouds with a cotton-like appearance
  abbreviation: Cu

--------------------------------------------------------------------------------
*/

const float clouds_radius_cu     = planet_radius + CLOUDS_CUMULUS_ALTITUDE;
const float clouds_thickness_cu  = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
const float clouds_top_radius_cu = clouds_radius_cu + clouds_thickness_cu;
float clouds_extinction_coeff_cu = mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y)));
float clouds_scattering_coeff_cu = clouds_extinction_coeff_cu * mix(1.00, 0.66, rainStrength);

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float altitude_shaping_cu(float density, float altitude_fraction) {
	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) * 0.6;

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_density_cu(vec3 pos) {
	const float wind_angle = CLOUDS_CUMULUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CUMULUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_radius_cu || r > clouds_top_radius_cu) return 0.0;

	float altitude_fraction = 0.8 * (r - clouds_radius_cu) * rcp(clouds_thickness_cu);

	pos.xz += cameraPosition.xz + wind_velocity * world_age;

	// 2D noise for base shape and coverage
	vec2 noise = vec2(
		texture(noisetex, 0.000002 * pos.xz * rcp(CLOUDS_CUMULUS_SIZE)).x, // cloud coverage
		texture(noisetex, 0.000027 * pos.xz * rcp(CLOUDS_CUMULUS_SIZE)).w  // cloud shape
	);

	float density = mix(clouds_coverage_cu.x, clouds_coverage_cu.y, noise.x);
	      density = linear_step(1.0 - density, 1.0, noise.y);
	      density = altitude_shaping_cu(density, altitude_fraction);

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = 0.181 * texture(colortex7, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley_0 = texture(colortex6, (pos + 0.2 * wind) * 0.001 + curl * 1.0).x;
	float worley_1 = texture(colortex6, (pos + 0.4 * wind) * 0.005 + curl * 3.0).x;

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.6;

	density -= 0.33 * sqr(worley_0) * dampen(clamp01(1.0 - density));
	density -= 0.40 * sqr(worley_1) * dampen(clamp01(1.0 - density)) * detail_fade;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = 1.0 - pow(1.0 - density, mix(3.0, 8.0, altitude_fraction));
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_optical_depth_cu(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 0.1 * clouds_thickness_cu / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_density_cu(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_scattering_cu(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = clouds_scattering_coeff_cu;
	float extinct_amount = clouds_extinction_coeff_cu;

	float scattering_integral_times_density = (1.0 - step_transmittance) / clouds_extinction_coeff_cu;

	float powder_effect = clouds_powder_effect(density, cos_theta);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase;
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= 0.55 * mix(lift(clamp01(clouds_scattering_coeff_cu / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5) * powder_effect;
		extinct_amount *= 0.4;
		phase_g *= 0.8;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density;
}

vec4 draw_clouds_cu(vec3 ray_dir, vec3 clear_sky, float dither) {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

	const uint  primary_steps_horizon = CLOUDS_CUMULUS_PRIMARY_STEPS_H;
	const uint  primary_steps_zenith  = CLOUDS_CUMULUS_PRIMARY_STEPS_Z;
	const uint  lighting_steps        = CLOUDS_CUMULUS_LIGHTING_STEPS;
	const uint  ambient_steps         = CLOUDS_CUMULUS_AMBIENT_STEPS;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const float planet_albedo         = 0.4;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, abs(ray_dir.y)));

	vec3 air_viewer_pos = vec3(0.0, planet_radius + eyeAltitude, 0.0);

	vec2 dists = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_radius_cu, clouds_top_radius_cu);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(length(air_viewer_pos) - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0
	 || planet_intersected && length(air_viewer_pos) < clouds_radius_cu
	) { return vec4(0.0, 0.0, 0.0, 1.0); }

	float ray_length = min(dists.y - dists.x, max_ray_length);
	float step_length = ray_length * rcp(float(primary_steps));

	vec3 ray_step = ray_dir * step_length;

	vec3 ray_origin = air_viewer_pos + ray_dir * (dists.x + step_length * dither);

	vec2 scattering = vec2(0.0); // x: direct light, y: skylight
	float transmittance = 1.0;

	float distance_sum = 0.0;
	float distance_weight_sum = 0.0;

	float cos_theta = dot(ray_dir, clouds_light_dir);
	float bounced_light = planet_albedo * clouds_light_dir.y * rcp_pi;

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i) {
		if (transmittance < min_transmittance) break;

		vec3 ray_pos = ray_origin + ray_step * i;

		float altitude_fraction = (length(ray_pos) - clouds_radius_cu) * rcp(clouds_thickness_cu);

		float density = clouds_density_cu(ray_pos);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, distance_to_sample * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * clouds_extinction_coeff_cu * step_length;
		float step_transmittance = exp(-step_optical_depth);

		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays

		float light_optical_depth  = clouds_optical_depth_cu(ray_pos, clouds_light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_optical_depth_cu(ray_pos, sky_dir, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_thickness_cu; // guess optical depth to the ground using altitude fraction and density from this sample

		scattering += clouds_scattering_cu(
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

	// get main light color for this layer
	vec3 light_color = atmosphere_transmittance(ray_origin, clouds_light_dir) * base_light_color * sunlight_color;

	// remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	return vec4(clouds_scattering, clouds_transmittance);
}

#endif // CLOUDS_INCLUDED
