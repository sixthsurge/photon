#if !defined INCLUDE_SKY_CLOUDS
#define INCLUDE_SKY_CLOUDS

#include "/include/sky/atmosphere.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

float day_factor = smoothstep(0.0, 0.3, abs(sun_dir.y));

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

#if CLOUDS_AERIAL_PERSPECTIVE_BOOST != 0
	ray_end = mix(ray_origin, ray_end, float(1 << CLOUDS_AERIAL_PERSPECTIVE_BOOST));
#endif

	if (length_squared(ray_origin) < length_squared(ray_end)) {
		vec3 trans_0 = atmosphere_transmittance(ray_origin, ray_dir);
		vec3 trans_1 = atmosphere_transmittance(ray_end,    ray_dir);

		air_transmittance = clamp01(trans_0 / trans_1);
	} else {
		vec3 trans_0 = atmosphere_transmittance(ray_origin, -ray_dir);
		vec3 trans_1 = atmosphere_transmittance(ray_end,    -ray_dir);

		air_transmittance = clamp01(trans_1 / trans_0);
	}

	// Blend to rain color during rain
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

#ifdef CLOUDS_CU
const float clouds_radius_cu     = planet_radius + CLOUDS_CU_ALTITUDE;
const float clouds_thickness_cu  = CLOUDS_CU_ALTITUDE * CLOUDS_CU_THICKNESS;
const float clouds_top_radius_cu = clouds_radius_cu + clouds_thickness_cu;
float clouds_extinction_coeff_cu = mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y))) * (1.0 - 0.33 * rainStrength) * CLOUDS_CU_DENSITY;
float clouds_scattering_coeff_cu = clouds_extinction_coeff_cu * mix(1.00, 0.66, rainStrength);
float dynamic_thickness_cu       = mix(0.5, 1.0, smoothstep(0.4, 0.6, clouds_coverage_cu.y));

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float altitude_shaping_cu(float density, float altitude_fraction) {
	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) * 0.6;

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_density_cu(vec3 pos) {
	const float wind_angle = CLOUDS_CU_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CU_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_radius_cu || r > clouds_top_radius_cu) return 0.0;

	float altitude_fraction = 0.8 * (r - clouds_radius_cu) * rcp(clouds_thickness_cu * dynamic_thickness_cu);

	pos.xz += cameraPosition.xz + wind_velocity * world_age;

	// 2D noise for base shape and coverage
	vec2 noise = vec2(
		texture(noisetex, (0.000002 / CLOUDS_CU_SIZE) * pos.xz).x, // cloud coverage
		texture(noisetex, (0.000027 / CLOUDS_CU_SIZE) * pos.xz).w  // cloud shape
	);

	float density = mix(clouds_coverage_cu.x, clouds_coverage_cu.y, noise.x);
	      density = linear_step(1.0 - density, 1.0, noise.y);
	      density = altitude_shaping_cu(density, altitude_fraction);

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = (0.181 * CLOUDS_CU_CURL_STRENGTH) * texture(colortex7, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley_0 = texture(colortex6, (pos + 0.2 * wind) * 0.001 + curl * 1.0).x;
	float worley_1 = texture(colortex6, (pos + 0.4 * wind) * 0.005 + curl * 3.0).x;

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.6;

	density -= (0.33 * CLOUDS_CU_DETAIL_STRENGTH) * sqr(worley_0) * dampen(clamp01(1.0 - density));
	density -= (0.40 * CLOUDS_CU_DETAIL_STRENGTH) * sqr(worley_1) * dampen(clamp01(1.0 - density)) * detail_fade;

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

#if defined PROGRAM_DEFERRED0
	const uint  primary_steps_horizon = CLOUDS_CU_PRIMARY_STEPS_H / 2;
	const uint  primary_steps_zenith  = CLOUDS_CU_PRIMARY_STEPS_Z / 2;
#else
	const uint  primary_steps_horizon = CLOUDS_CU_PRIMARY_STEPS_H;
	const uint  primary_steps_zenith  = CLOUDS_CU_PRIMARY_STEPS_Z;
#endif
	const uint  lighting_steps        = CLOUDS_CU_LIGHTING_STEPS;
	const uint  ambient_steps         = CLOUDS_CU_AMBIENT_STEPS;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const float planet_albedo         = 0.4;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, abs(ray_dir.y)));

#if defined PROGRAM_DEFERRED0
	vec3 air_viewer_pos = vec3(0.0, planet_radius, 0.0);
#else
	vec3 air_viewer_pos = vec3(0.0, planet_radius + eyeAltitude, 0.0);
#endif

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

		float altitude_fraction = (length(ray_pos) - clouds_radius_cu) * rcp(clouds_thickness_cu);

		float density = clouds_density_cu(ray_pos);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, distance_to_sample * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * clouds_extinction_coeff_cu * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_optical_depth_cu(ray_pos, light_dir, hash.x, lighting_steps);
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

	// Get main light color for this layer
	vec3 light_color  = moonlit ? moon_color : sun_color;
	     light_color *= sunlight_color * atmosphere_transmittance(ray_origin, light_dir);
		 light_color *= 1.0 - rainStrength;

	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	return vec4(clouds_scattering, clouds_transmittance);
}
#endif

/*
--------------------------------------------------------------------------------

  2nd layer: altocumulus clouds

  altitude: 2700-3375
  description: mid-level, puffy clouds
  abbreviation: Ac

--------------------------------------------------------------------------------
*/

#ifdef CLOUDS_AC
const float clouds_radius_ac     = planet_radius + CLOUDS_AC_ALTITUDE;
const float clouds_thickness_ac  = CLOUDS_AC_ALTITUDE * CLOUDS_AC_THICKNESS;
const float clouds_top_radius_ac = clouds_radius_ac + clouds_thickness_ac;
float clouds_extinction_coeff_ac = mix(0.05, 0.1, day_factor) * CLOUDS_AC_DENSITY * (1.0 - 0.33 * rainStrength);
float clouds_scattering_coeff_ac = clouds_extinction_coeff_ac * mix(1.00, 0.66, rainStrength);
float dynamic_thickness_ac       = mix(0.5, 1.0, smoothstep(0.4, 0.6, clouds_coverage_ac.y));

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float altitude_shaping_ac(float density, float altitude_fraction) {
	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) * 0.6;

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_density_ac(vec3 pos) {
	const float wind_angle = CLOUDS_AC_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_AC_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_radius_ac || r > clouds_top_radius_ac) return 0.0;

	float altitude_fraction = 0.8 * (r - clouds_radius_ac) * rcp(clouds_thickness_ac * dynamic_thickness_ac);

	pos.xz += cameraPosition.xz + wind_velocity * world_age;

	// 2D noise for base shape and coverage
	vec2 noise = vec2(
		texture(noisetex, (0.000005 / CLOUDS_AC_SIZE) * pos.xz).x, // cloud coverage
		texture(noisetex, (0.000047 / CLOUDS_AC_SIZE) * pos.xz + 0.3).w  // cloud shape
	);

	float density = mix(clouds_coverage_ac.x, clouds_coverage_ac.y, cubic_smooth(noise.x));
	      density = linear_step(1.0 - density, 1.0, noise.y);
	      density = altitude_shaping_ac(density, altitude_fraction);

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = (0.181 * CLOUDS_AC_CURL_STRENGTH) * texture(colortex7, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley = texture(colortex6, (pos + 0.2 * wind) * 0.001 + curl * 1.0).x;

	density -= (0.44 * CLOUDS_AC_DETAIL_STRENGTH) * sqr(worley) * dampen(clamp01(1.0 - density));

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = 1.0 - pow(1.0 - density, mix(3.0, 8.0, altitude_fraction));
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_optical_depth_ac(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 0.15 * clouds_thickness_ac / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_density_ac(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_scattering_ac(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = clouds_scattering_coeff_ac;
	float extinct_amount = clouds_extinction_coeff_ac;

	float scattering_integral_times_density = (1.0 - step_transmittance) / clouds_extinction_coeff_ac;

	float powder_effect = clouds_powder_effect(density, cos_theta);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase;
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= 0.55 * mix(lift(clamp01(clouds_scattering_coeff_ac / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5) * powder_effect;
		extinct_amount *= 0.4;
		phase_g *= 0.8;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density;
}

vec4 draw_clouds_ac(vec3 ray_dir, vec3 clear_sky, float dither) {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

#if defined PROGRAM_DEFERRED0
	const uint  primary_steps_horizon = CLOUDS_AC_PRIMARY_STEPS_H / 2;
	const uint  primary_steps_zenith  = CLOUDS_AC_PRIMARY_STEPS_Z / 2;
#else
	const uint  primary_steps_horizon = CLOUDS_AC_PRIMARY_STEPS_H;
	const uint  primary_steps_zenith  = CLOUDS_AC_PRIMARY_STEPS_Z;
#endif
	const uint  lighting_steps        = CLOUDS_AC_LIGHTING_STEPS;
	const uint  ambient_steps         = CLOUDS_AC_AMBIENT_STEPS;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const float planet_albedo         = 0.4;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, abs(ray_dir.y)));

#if defined PROGRAM_DEFERRED0
	vec3 air_viewer_pos = vec3(0.0, planet_radius, 0.0);
#else
	vec3 air_viewer_pos = vec3(0.0, planet_radius + eyeAltitude, 0.0);
#endif

	vec2 dists = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_radius_ac, clouds_top_radius_ac);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(length(air_viewer_pos) - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0
	 || planet_intersected && length(air_viewer_pos) < clouds_radius_ac
	) { return vec4(0.0, 0.0, 0.0, 1.0); }

	float ray_length = min(dists.y - dists.x, max_ray_length);
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

	bool moonlit = sun_dir.y < -0.045;
	vec3 light_dir = moonlit ? moon_dir : sun_dir;
	float cos_theta = dot(ray_dir, light_dir);
	float bounced_light = planet_albedo * light_dir.y * rcp_pi;

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i) {
		if (transmittance < min_transmittance) break;

		vec3 ray_pos = ray_origin + ray_step * i;

		float altitude_fraction = (length(ray_pos) - clouds_radius_ac) * rcp(clouds_thickness_ac);

		float density = clouds_density_ac(ray_pos);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, distance_to_sample * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * clouds_extinction_coeff_ac * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_optical_depth_ac(ray_pos, light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_optical_depth_ac(ray_pos, sky_dir, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_thickness_ac; // guess optical depth to the ground using altitude fraction and density from this sample

		scattering += clouds_scattering_ac(
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
	vec3 light_color  = moonlit ? moon_color : sun_color;
	     light_color *= sunlight_color * atmosphere_transmittance(ray_origin, light_dir);
		 light_color *= 1.0 - rainStrength;

	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	return vec4(clouds_scattering, clouds_transmittance);
}
#endif

/*
--------------------------------------------------------------------------------

  3rd layer: cirrus clouds

  altitude: 10000m
  description: high-altitude, feather-like planar clouds
  abbreviation: Ci

--------------------------------------------------------------------------------
*/

#ifdef CLOUDS_CI
const float clouds_radius_ci     = planet_radius + CLOUDS_CI_ALTITUDE;
const float clouds_thickness_ci  = CLOUDS_CI_ALTITUDE * CLOUDS_AC_THICKNESS;
const float clouds_top_radius_ci = clouds_radius_ci + clouds_thickness_ci;
const float clouds_extinction_coeff_ci = 0.15;
const float clouds_scattering_coeff_ci = clouds_extinction_coeff_ci;

// from https://iquilezles.org/articles/gradientnoise/
vec2 perlin_gradient(vec2 coord) {
	vec2 i = floor(coord);
	vec2 f = fract(coord);

	vec2 u  = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * ( f *( f - 2.0) + 1.0);

	vec2 g0 = hash2(i + vec2(0.0, 0.0));
	vec2 g1 = hash2(i + vec2(1.0, 0.0));
	vec2 g2 = hash2(i + vec2(0.0, 1.0));
	vec2 g3 = hash2(i + vec2(1.0, 1.0));

	float v0 = dot(g0, f - vec2(0.0, 0.0));
	float v1 = dot(g1, f - vec2(1.0, 0.0));
	float v2 = dot(g2, f - vec2(0.0, 1.0));
	float v3 = dot(g3, f - vec2(1.0, 1.0));

	return vec2(
		g0 + u.x * (g1 - g0) + u.y * (g2 - g0) + u.x * u.y * (g0 - g1 - g2 + g3) + // d/dx
		du * (u.yx * (v0 - v1 - v2 + v3) + vec2(v1, v2) - v0)                      // d/dy
	);
}

vec2 curl2D(vec2 coord) {
	vec2 gradient = perlin_gradient(coord);
	return vec2(gradient.y, -gradient.x);
}

float clouds_density_ci(vec2 coord, float altitude_fraction, out float cirrus, out float cirrocumulus) {
	const float wind_angle = CLOUDS_CI_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CI_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	coord = coord + cameraPosition.xz;
	coord = coord + wind_velocity * world_age;

	vec2 curl = curl2D(0.00002 * coord) * 0.5
	          + curl2D(0.00004 * coord) * 0.25
			  + curl2D(0.00008 * coord) * 0.125;

	float density = 0.0;
	float height_shaping = 1.0 - abs(1.0 - 2.0 * altitude_fraction);

	// -----------------
	//   Cirrus Clouds
	// -----------------

	cirrus = 0.7 * texture(noisetex, (0.000001 / CLOUDS_CI_SIZE) * coord + (0.004 * CLOUDS_CI_CURL_STRENGTH) * curl).x
	       + 0.3 * texture(noisetex, (0.000008 / CLOUDS_CI_SIZE) * coord + (0.008 * CLOUDS_CI_CURL_STRENGTH) * curl).x;
	cirrus = linear_step(0.7 - clouds_coverage_ci.x, 1.0, cirrus);

	float detail_amplitude = 0.2;
	float detail_frequency = 0.00002;
	float curl_strength    = 0.1 * CLOUDS_CI_CURL_STRENGTH;

	for (int i = 0; i < 4; ++i) {
		float detail = texture(noisetex, coord * detail_frequency + curl * curl_strength).x;

		cirrus -= detail * detail_amplitude;

		detail_amplitude *= 0.6;
		detail_frequency *= 2.0;
		curl_strength *= 4.0;

		coord += 0.3 * wind_velocity * world_age;
	}

	density += mix(1.0, 0.75, day_factor) * cube(max0(cirrus)) * sqr(height_shaping) * CLOUDS_CI_DENSITY;

	// -----------------------
	//   Cirrocumulus Clouds
	// -----------------------

	float coverage = texture(noisetex, (0.0000026 / CLOUDS_CC_SIZE) * coord + (0.004 * CLOUDS_CC_CURL_STRENGTH) * curl).w;
		  coverage = 5.0 * linear_step(0.3, 0.7, clouds_coverage_ci.y * coverage);

	cirrocumulus = dampen(texture(noisetex, (0.000025 * rcp(CLOUDS_CC_SIZE)) * coord + (0.1 * CLOUDS_CC_CURL_STRENGTH) * curl).w);
	cirrocumulus = linear_step(1.0 - coverage, 1.0, cirrocumulus);

	// detail
	cirrocumulus -= texture(noisetex, coord * 0.00005 + (0.1 * CLOUDS_CC_CURL_STRENGTH) * curl).y * (CLOUDS_CC_DETAIL_STRENGTH);
	cirrocumulus -= texture(noisetex, coord * 0.00015 + (0.4 * CLOUDS_CC_CURL_STRENGTH) * curl).y * (CLOUDS_CC_DETAIL_STRENGTH * 0.25);
	cirrocumulus -= texture(noisetex, coord * 0.00040 + (0.9 * CLOUDS_CC_CURL_STRENGTH) * curl).y * (CLOUDS_CC_DETAIL_STRENGTH * 0.10);
	cirrocumulus  = max0(cirrocumulus);

	density += 0.2 * cube(max0(cirrocumulus)) * height_shaping * dampen(height_shaping) * CLOUDS_CC_DENSITY;

	return density;
}

float clouds_optical_depth_ci(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither
) {
	const uint step_count      = CLOUDS_CI_LIGHTING_STEPS;
	const float max_ray_length = 1e3;
	const float step_growth    = 1.5;

	// Assuming ray_origin is between inner and outer boundary, find distance to closest layer
	// boundary
	vec2 inner_sphere = intersect_sphere(ray_origin, ray_dir, clouds_radius_ci - 0.5 * CLOUDS_CI_THICKNESS);
	vec2 outer_sphere = intersect_sphere(ray_origin, ray_dir, clouds_radius_ci + 0.5 * CLOUDS_CI_THICKNESS);
	float ray_length = (inner_sphere.y >= 0.0) ? inner_sphere.x : outer_sphere.y;
	      ray_length = min(ray_length, max_ray_length);

	// Find initial step length a so that Σ(ar^i) = rayLength
	float step_coeff = (step_growth - 1.0) / (pow(step_growth, float(step_count)) - 1.0) / step_growth;
	float step_length = ray_length * step_coeff;

	vec3 ray_pos  = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;

		vec3 dithered_pos = ray_pos + ray_step.xyz * dither;

		float r = length(dithered_pos);
		float altitude_fraction = (r - clouds_radius_ci) * rcp(CLOUDS_CI_THICKNESS) + 0.5;

		vec3 sphere_pos = dithered_pos * (clouds_radius_ci / r);

		float cirrus, cirrocumulus;
		optical_depth += clouds_density_ci(sphere_pos.xz, altitude_fraction, cirrus, cirrocumulus) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_scattering_ci(
	float density,
	float view_transmittance,
	float light_optical_depth,
	float cos_theta
) {
	vec2 scattering = vec2(0.0);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = vec3(0.7, 0.9, 0.3);

	float powder_effect = 4.0 * (1.0 - exp(-40.0 * density));
	      powder_effect = mix(powder_effect, 1.0, pow1d5(cos_theta * 0.5 + 0.5));

	float scatter_amount = clouds_scattering_coeff_ci;
	float extinct_amount = clouds_extinction_coeff_ci * (1.0 + 0.5 * max0(smoothstep(0.0, 0.15, abs(sun_dir.y)) - smoothstep(0.5, 0.7, clouds_coverage_ci.x)));

	for (uint i = 0u; i < 4u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount * light_optical_depth) * phase * powder_effect; // direct light
		scattering.y += scatter_amount * exp(-0.33 * CLOUDS_CI_THICKNESS * extinct_amount * density) * isotropic_phase; // sky light

		scatter_amount *= 0.5;
		extinct_amount *= 0.5;
		phase_g *= 0.8;

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	float scattering_integral = (1.0 - view_transmittance) / clouds_extinction_coeff_ci;
	return scattering * scattering_integral;
}

vec4 draw_clouds_ci(vec3 ray_dir, vec3 clear_sky, float dither) {
	// ---------------
	//   Ray Casting
	// ---------------

#if defined PROGRAM_DEFERRED0
	vec3 air_viewer_pos = vec3(0.0, planet_radius, 0.0);
#else
	vec3 air_viewer_pos = vec3(0.0, planet_radius + eyeAltitude, 0.0);
#endif

	float r = length(air_viewer_pos);

	vec2 dists = intersect_sphere(air_viewer_pos, ray_dir, clouds_radius_ci);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0                              // plane not intersected
	 || planet_intersected && r < clouds_radius_ci // planet blocking clouds
	) { return vec4(0.0, 0.0, 0.0, 1.0); }

	float distance_to_sphere = (r < clouds_radius_ci) ? dists.y : dists.x;
	vec3 sphere_pos = air_viewer_pos + ray_dir * distance_to_sphere;

	// ------------------
	//   Cloud Lighting
	// ------------------

	bool moonlit = sun_dir.y < -0.049;
	vec3 light_dir = moonlit ? moon_dir : sun_dir;
	float cos_theta = dot(ray_dir, light_dir);

	float cirrus, cirrocumulus;
	float density = clouds_density_ci(sphere_pos.xz, 0.5, cirrus, cirrocumulus);
	if (density < eps) return vec4(0.0, 0.0, 0.0, 1.0);

	float light_optical_depth = clouds_optical_depth_ci(sphere_pos, light_dir, dither);
	float view_optical_depth  = density * clouds_extinction_coeff_ci * CLOUDS_CI_THICKNESS * rcp(abs(ray_dir.y) + eps);
	float view_transmittance  = exp(-view_optical_depth);

	vec2 scattering = clouds_scattering_ci(density, view_transmittance, light_optical_depth, cos_theta);

	// Get main light color for this layer
	float r_sq = dot(sphere_pos, sphere_pos);
	float rcp_r = inversesqrt(r_sq);
	float mu = dot(sphere_pos, light_dir) * rcp_r;
	float rr = r_sq * rcp_r - 1500.0 * clamp01(linear_step(0.0, 0.05, cirrocumulus) * (1.0 - linear_step(0.0, 0.1, cirrus)) + cirrocumulus);

	vec3 light_color  = moonlit ? moon_color : sun_color;
	     light_color *= sunlight_color * atmosphere_transmittance(mu, rr);
		 light_color *= 1.0 - rainStrength;

	// Remap the transmittance so that min_transmittance is 0
	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, view_transmittance, air_viewer_pos, sphere_pos, ray_dir, clear_sky);

	return vec4(clouds_scattering, view_transmittance);
}
#endif

vec4 draw_clouds(vec3 ray_dir, vec3 clear_sky, float dither) {
	vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);

#ifdef CLOUDS_CU
	vec4 clouds_cu = draw_clouds_cu(ray_dir, clear_sky, dither);
	clouds = clouds_cu;
	if (clouds.a < 1e-3) return clouds;
#endif

#ifdef CLOUDS_AC
	vec4 clouds_ac = draw_clouds_ac(ray_dir, clear_sky, dither);
	clouds.rgb += clouds_ac.rgb * clouds.a;
	clouds.a   *= clouds_ac.a;
	if (clouds.a < 1e-3) return clouds;
#endif

#ifdef CLOUDS_CI
	vec4 clouds_ci = draw_clouds_ci(ray_dir, clear_sky, dither);
	clouds.rgb += clouds_ci.rgb * clouds.a;
	clouds.a   *= clouds_ci.a;
#endif

	return max0(clouds);
}

#endif // INCLUDE_SKY_CLOUDS
