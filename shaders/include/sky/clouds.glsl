#if !defined INCLUDE_SKY_CLOUDS
#define INCLUDE_SKY_CLOUDS

#include "/include/sky/atmosphere.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

struct CloudsResult {
	vec3 scattering;
	float transmittance;
	float apparent_distance;
};

const CloudsResult clouds_not_hit = CloudsResult(
	vec3(0.0),
	1.0,
	1e6
);

uniform float day_factor;

float clouds_phase_single(float cos_theta) { // Single scattering phase function
	float forwards_a = klein_nishina_phase(cos_theta, 2600.0); // this gives a nice glow very close to the sun
	float forwards_b = henyey_greenstein_phase(cos_theta, 0.8); 

	return 0.8 * max(forwards_a, forwards_b)               // forwards lobe (max'ing them is completely nonsensical but it looks nice)
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

  1st layer: cumulus/stratocumulus/stratus clouds

  altitude: 1200-2400m
  description: low-level, cauliflower-shaped clouds with a cotton-like appearance
  abbreviation: Cu

--------------------------------------------------------------------------------
*/

#ifdef CLOUDS_CUMULUS // jcu
const float clouds_cumulus_radius      = planet_radius + CLOUDS_CUMULUS_ALTITUDE;
const float clouds_cumulus_thickness   = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
const float clouds_cumulus_top_radius  = clouds_cumulus_radius + clouds_cumulus_thickness;

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float clouds_cumulus_altitude_shaping(float density, float altitude_fraction) {
	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) * 0.6;

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_cumulus_density(vec3 pos, vec2 detail_weights, vec2 edge_sharpening, float dynamic_thickness) {
	const float wind_angle = CLOUDS_CUMULUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CUMULUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_cumulus_radius || r > clouds_cumulus_top_radius) return 0.0;

	float altitude_fraction = 0.8 * (r - clouds_cumulus_radius) * rcp(clouds_cumulus_thickness * dynamic_thickness);

	pos.xz += cameraPosition.xz * CLOUDS_SCALE + wind_velocity * world_age;

	// 2D noise for base shape and coverage
	vec2 noise = vec2(
		texture(noisetex, (0.000002 / CLOUDS_CUMULUS_SIZE) * pos.xz).x, // cloud coverage
		texture(noisetex, (0.000027 / CLOUDS_CUMULUS_SIZE) * pos.xz).w  // cloud shape
	);

	float density_cu = mix(clouds_cumulus_coverage.x, clouds_cumulus_coverage.y, noise.x);
	      density_cu = linear_step(1.0 - density_cu, 1.0, noise.y);

	float density_st = linear_step(0.30, 0.70, noise.x) * linear_step(0.10, 0.90, noise.y);

	float density  = mix(density_cu, density_st, clouds_stratus_amount);
	      density  = clouds_cumulus_altitude_shaping(density, altitude_fraction);
		  density -= density * linear_step(0.0, 0.5, clouds_cumulus_congestus_amount);

	if (density < eps) return 0.0;

#ifndef PROGRAM_PREPARE
	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = (0.181 * CLOUDS_CUMULUS_CURL_STRENGTH) * texture(colortex7, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley_0 = texture(colortex6, (pos + 0.2 * wind) * 0.001 + curl * 1.0).x;
	float worley_1 = texture(colortex6, (pos + 0.4 * wind) * 0.005 + curl * 3.0).x;
#else
	const float worley_0 = 0.5;
	const float worley_1 = 0.5;
#endif

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.6;

	density -= detail_weights.x * sqr(worley_0) * dampen(clamp01(1.0 - density));
	density -= detail_weights.y * sqr(worley_1) * dampen(clamp01(1.0 - density)) * detail_fade;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = 1.0 - pow(1.0 - density, mix(edge_sharpening.x, edge_sharpening.y, altitude_fraction));
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_cumulus_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	vec2 detail_weights,
	vec2 edge_sharpening,
	float dynamic_thickness,
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
		optical_depth += clouds_cumulus_density(ray_pos + ray_step.xyz * dither, detail_weights, edge_sharpening, dynamic_thickness) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_cumulus_scattering(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float extinction_coeff,
	float scattering_coeff,
	float step_transmittance,
	float cos_theta,
	float altocumulus_shadow,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = scattering_coeff;
	float extinct_amount = extinction_coeff;

	float scattering_integral_times_density = (1.0 - step_transmittance) / extinction_coeff;

	float powder_effect = clouds_powder_effect(density + density * clouds_stratus_amount, cos_theta);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase * (1.0 - 0.8 * altocumulus_shadow);
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.x += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase * altocumulus_shadow * 0.2; // fake bounced lighting from the layer above
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= 0.55 * mix(lift(clamp01(scattering_coeff / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5) * powder_effect;
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

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, abs(ray_dir.y)));

	float r = length(air_viewer_pos);

	vec2 dists = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_cumulus_radius, clouds_cumulus_top_radius);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;
	bool terrain_intersected = distance_to_terrain >= 0.0 && r < clouds_cumulus_radius && distance_to_terrain * CLOUDS_SCALE < dists.y;

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

	float altocumulus_shadow = linear_step(0.5, 0.6, clouds_altocumulus_coverage.x) * dampen(day_factor);

	bool  moonlit            = sun_dir.y < -0.04;
	vec3  light_dir          = moonlit ? moon_dir : sun_dir;
	float cos_theta          = dot(ray_dir, light_dir);
	float bounced_light      = planet_albedo * light_dir.y * rcp_pi;

	float extinction_coeff   = mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y))) * (1.0 - 0.33 * rainStrength) * (1.0 - 0.6 * altocumulus_shadow) * CLOUDS_CUMULUS_DENSITY;
	float scattering_coeff   = extinction_coeff * mix(1.00, 0.66, rainStrength);

	float dynamic_thickness  = mix(0.5, 1.0, smoothstep(0.4, 0.6, clouds_cumulus_coverage.y));
	vec2  detail_weights     = mix(vec2(0.33, 0.40), vec2(0.25, 0.20), sqr(clouds_stratus_amount)) * CLOUDS_CUMULUS_DETAIL_STRENGTH;
	vec2  edge_sharpening    = mix(vec2(3.0, 8.0), vec2(1.0, 2.0), clouds_stratus_amount);

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i) {
		if (transmittance < min_transmittance) break;

		vec3 ray_pos = ray_origin + ray_step * i;

		float altitude_fraction = (length(ray_pos) - clouds_cumulus_radius) * rcp(clouds_cumulus_thickness);

		float density = clouds_cumulus_density(ray_pos, detail_weights, edge_sharpening, dynamic_thickness);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, distance_to_sample * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * extinction_coeff * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_cumulus_optical_depth(ray_pos, light_dir, detail_weights, edge_sharpening, dynamic_thickness, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_cumulus_optical_depth(ray_pos, sky_dir, detail_weights, edge_sharpening, dynamic_thickness, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_cumulus_thickness; // guess optical depth to the ground using altitude fraction and density from this sample

		scattering += clouds_cumulus_scattering(
			density,
			light_optical_depth,
			sky_optical_depth,
			ground_optical_depth,
			extinction_coeff,
			scattering_coeff,
			step_transmittance,
			cos_theta,
			altocumulus_shadow,
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
		 light_color *= 1.0 - rainStrength;

	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	float apparent_distance = (distance_weight_sum == 0.0)
		? 1e6
		: (distance_sum / distance_weight_sum) + distance(air_viewer_pos, ray_origin);

	return CloudsResult(
		clouds_scattering,
		clouds_transmittance,
		apparent_distance
	);
}
#endif

/*
--------------------------------------------------------------------------------

  alt. 1st layer: cumulus congestus clouds

  altitude: 400-10000m
  description: massive clouds forming a ring around the player
  abbreviation: Cu con

--------------------------------------------------------------------------------
*/

#ifdef CLOUDS_CUMULUS_CONGESTUS // jcucon
const float clouds_cumulus_congestus_radius           = planet_radius + CLOUDS_CUMULUS_CONGESTUS_ALTITUDE;
const float clouds_cumulus_congestus_thickness        = CLOUDS_CUMULUS_CONGESTUS_ALTITUDE * CLOUDS_CUMULUS_CONGESTUS_THICKNESS;
const float clouds_cumulus_congestus_top_radius       = clouds_cumulus_congestus_radius + clouds_cumulus_congestus_thickness;
const float clouds_cumulus_congestus_distance         = 10000.0;
const float clouds_cumulus_congestus_end_distance     = 50000.0;
const float clouds_cumulus_congestus_extinction_coeff = 0.08;
float clouds_cumulus_congestus_scattering_coeff       = clouds_cumulus_congestus_extinction_coeff * (1.0 - 0.33 * rainStrength);

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float clouds_cumulus_congestus_altitude_shaping(float density, float altitude_fraction) {
	// Carve egg shape
	density -= pow1d5(linear_step(0.2, 1.0, altitude_fraction)) * 0.6;

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

	pos.xz += cameraPosition.xz * CLOUDS_SCALE + wind_velocity * (world_age + 50.0 * sqr(altitude_fraction));

	// 2D noise for base shape and coverage
	float noise = texture(noisetex, (0.000002 / CLOUDS_CUMULUS_CONGESTUS_SIZE) * pos.xz).w;

	float density  = 1.2 * linear_step(0.2, 1.0, sqr(noise)) * linear_step(0.5, 0.75, clouds_cumulus_congestus_amount);
	      density  = clouds_cumulus_congestus_altitude_shaping(density, altitude_fraction);
		  density *= 4.0 * distance_fraction * (1.0 - distance_fraction);

	if (density < eps) return 0.0;

#ifndef PROGRAM_PREPARE
	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = (0.181 * CLOUDS_CUMULUS_CONGESTUS_CURL_STRENGTH) * texture(colortex7, 0.0002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley_0 = texture(colortex6, (pos + 0.2 * wind) * 0.00016 + curl * 1.0).x;
	float worley_1 = texture(colortex6, (pos + 0.4 * wind) * 0.0010 + curl * 3.0).x;
#else
	const float worley_0 = 0.5;
	const float worley_1 = 0.5;
#endif

	float detail_fade = 0.20 * smoothstep(0.85, 1.0, 1.0 - altitude_fraction)
	                  - 0.35 * smoothstep(0.05, 0.5, altitude_fraction) + 0.6;

	density -= (0.25 * CLOUDS_CUMULUS_CONGESTUS_DETAIL_STRENGTH) * sqr(worley_0) * dampen(clamp01(1.0 - density));
	density -= (0.10 * CLOUDS_CUMULUS_CONGESTUS_DETAIL_STRENGTH) * sqr(worley_1) * dampen(clamp01(1.0 - density)) * detail_fade;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = 1.0 - pow(max0(1.0 - density), mix(2.0, 7.0, altitude_fraction));
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
		extinct_amount *= 0.5;
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
		 light_color *= 1.0 - rainStrength;

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
		clouds_scattering,
		clouds_transmittance,
		apparent_distance
	);

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

#ifdef CLOUDS_ALTOCUMULUS // jac
const float clouds_altocumulus_radius      = planet_radius + CLOUDS_ALTOCUMULUS_ALTITUDE;
const float clouds_altocumulus_thickness   = CLOUDS_ALTOCUMULUS_ALTITUDE * CLOUDS_ALTOCUMULUS_THICKNESS;
const float clouds_altocumulus_top_radius  = clouds_altocumulus_radius + clouds_altocumulus_thickness;

// altitude_fraction := 0 at the bottom of the cloud layer and 1 at the top
float clouds_altocumulus_altitude_shaping(float density, float altitude_fraction) {
	// Carve egg shape
	density -= smoothstep(0.2, 1.0, altitude_fraction) * 0.6;

	// Reduce density at the bottom of the cloud
	density *= smoothstep(0.0, 0.2, altitude_fraction);

	return density;
}

float clouds_altocumulus_density(vec3 pos) {
	const float wind_angle = CLOUDS_ALTOCUMULUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_ALTOCUMULUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	float r = length(pos);
	if (r < clouds_altocumulus_radius || r > clouds_altocumulus_top_radius) return 0.0;

	float dynamic_thickness = mix(0.5, 1.0, smoothstep(0.4, 0.6, clouds_altocumulus_coverage.y));
	float altitude_fraction = 0.8 * (r - clouds_altocumulus_radius) * rcp(clouds_altocumulus_thickness * dynamic_thickness);

	pos.xz += cameraPosition.xz * CLOUDS_SCALE + wind_velocity * world_age;

	// 2D noise for base shape and coverage
	vec2 noise = vec2(
		texture(noisetex, (0.000005 / CLOUDS_ALTOCUMULUS_SIZE) * pos.xz).x, // cloud coverage
		texture(noisetex, (0.000047 / CLOUDS_ALTOCUMULUS_SIZE) * pos.xz + 0.3).w  // cloud shape
	);

	float density = mix(clouds_altocumulus_coverage.x, clouds_altocumulus_coverage.y, cubic_smooth(noise.x));
	      density = linear_step(1.0 - density, 1.0, noise.y);
	      density = clouds_altocumulus_altitude_shaping(density, altitude_fraction);

	if (density < eps) return 0.0;

#ifndef PROGRAM_PREPARE
	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = (0.181 * CLOUDS_ALTOCUMULUS_CURL_STRENGTH) * texture(colortex7, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitude_fraction);
	vec3 wind = vec3(wind_velocity * world_age, 0.0).xzy;

	// 3D worley noise for detail
	float worley = texture(colortex6, (pos + 0.2 * wind) * 0.001 + curl * 1.0).x;
#else
	const float worley = 0.5;
#endif

	density -= (0.44 * CLOUDS_ALTOCUMULUS_DETAIL_STRENGTH) * sqr(worley) * dampen(clamp01(1.0 - density));

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = max0(density);
	density  = 1.0 - pow(1.0 - density, mix(3.0, 8.0, altitude_fraction));
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_altocumulus_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 0.15 * clouds_altocumulus_thickness / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_altocumulus_density(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_altocumulus_scattering(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float extinction_coeff,
	float scattering_coeff,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = scattering_coeff;
	float extinct_amount = extinction_coeff;

	float scattering_integral_times_density = (1.0 - step_transmittance) / extinction_coeff;

	float powder_effect = clouds_powder_effect(density, cos_theta);

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase;
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= 0.55 * mix(lift(clamp01(scattering_coeff / 0.1), 0.33), 1.0, cos_theta * 0.5 + 0.5) * powder_effect;
		extinct_amount *= 0.4;
		phase_g *= 0.8;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density;
}

CloudsResult draw_altocumulus_clouds(
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
	const uint  primary_steps_horizon = CLOUDS_ALTOCUMULUS_PRIMARY_STEPS_H / 2;
	const uint  primary_steps_zenith  = CLOUDS_ALTOCUMULUS_PRIMARY_STEPS_Z / 2;
#else
	const uint  primary_steps_horizon = CLOUDS_ALTOCUMULUS_PRIMARY_STEPS_H;
	const uint  primary_steps_zenith  = CLOUDS_ALTOCUMULUS_PRIMARY_STEPS_Z;
#endif
	const uint  lighting_steps        = CLOUDS_ALTOCUMULUS_LIGHTING_STEPS;
	const uint  ambient_steps         = CLOUDS_ALTOCUMULUS_AMBIENT_STEPS;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const float planet_albedo         = 0.4;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, abs(ray_dir.y)));

	float r = length(air_viewer_pos);

	vec2 dists = intersect_spherical_shell(air_viewer_pos, ray_dir, clouds_altocumulus_radius, clouds_altocumulus_top_radius);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;
	bool terrain_intersected = distance_to_terrain >= 0.0 && r < clouds_altocumulus_radius && distance_to_terrain * CLOUDS_SCALE < dists.y;

	if (dists.y < 0.0                                   // volume not intersected
	 || planet_intersected && r < clouds_altocumulus_radius // planet blocking clouds
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

	float high_coverage = linear_step(0.5, 0.6, clouds_altocumulus_coverage.x);

	float extinction_coeff = mix(0.05, 0.1, day_factor) * CLOUDS_ALTOCUMULUS_DENSITY * (1.0 - 0.85 * high_coverage * (dampen(time_noon + time_midnight) * 0.75 + 0.25)) * (1.0 - 0.33 * rainStrength);
	float scattering_coeff = extinction_coeff * mix(1.00, 0.66, rainStrength);

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

		float altitude_fraction = (length(ray_pos) - clouds_altocumulus_radius) * rcp(clouds_altocumulus_thickness);

		float density = clouds_altocumulus_density(ray_pos);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, distance_to_sample * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * extinction_coeff * step_length;
		float step_transmittance = exp(-step_optical_depth);

#if defined PROGRAM_DEFERRED0
		vec2 hash = vec2(0.0);
#else
		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays
#endif

		float light_optical_depth  = clouds_altocumulus_optical_depth(ray_pos, light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_altocumulus_optical_depth(ray_pos, sky_dir, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_altocumulus_thickness; // guess optical depth to the ground using altitude fraction and density from this sample

		scattering += clouds_altocumulus_scattering(
			density,
			light_optical_depth,
			sky_optical_depth,
			ground_optical_depth,
			extinction_coeff,
			scattering_coeff,
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
		 light_color *= 1.0 - rainStrength;
		 light_color *= 1.0 + 0.4 * high_coverage * dampen(time_noon);


	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, clouds_transmittance, air_viewer_pos, ray_origin, ray_dir, clear_sky);

	float apparent_distance = (distance_weight_sum == 0.0)
		? 1e6
		: (distance_sum / distance_weight_sum) + distance(air_viewer_pos, ray_origin);

	return CloudsResult(
		clouds_scattering,
		clouds_transmittance,
		apparent_distance
	);
}
#endif

/*
--------------------------------------------------------------------------------

  3rd layer: cirrus/cirrocumulus clouds

  altitude: 10000m
  description: high-altitude, feather-like planar clouds
  abbreviation: Ci

--------------------------------------------------------------------------------
*/

#ifdef CLOUDS_CIRRUS // jci
const float clouds_cirrus_radius     = planet_radius + CLOUDS_CIRRUS_ALTITUDE;
const float clouds_cirrus_thickness  = CLOUDS_CIRRUS_ALTITUDE * CLOUDS_ALTOCUMULUS_THICKNESS;
const float clouds_cirrus_top_radius = clouds_cirrus_radius + clouds_cirrus_thickness;
const float clouds_cirrus_extinction_coeff = 0.15;
const float clouds_cirrus_scattering_coeff = clouds_cirrus_extinction_coeff;

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

float clouds_cirrus_density(vec2 coord, float altitude_fraction, out float cirrus, out float cirrocumulus) {
	const float wind_angle = CLOUDS_CIRRUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CIRRUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	coord = coord + cameraPosition.xz * CLOUDS_SCALE;
	coord = coord + wind_velocity * world_age;

	vec2 curl = curl2D(0.00002 * coord) * 0.5
	          + curl2D(0.00004 * coord) * 0.25
			  + curl2D(0.00008 * coord) * 0.125;

	float density = 0.7 * texture(noisetex, (0.000001 / CLOUDS_CIRRUS_SIZE) * coord + (0.004 * CLOUDS_CIRRUS_CURL_STRENGTH) * curl).x
	              + 0.3 * texture(noisetex, (0.000008 / CLOUDS_CIRRUS_SIZE) * coord + (0.008 * CLOUDS_CIRRUS_CURL_STRENGTH) * curl).x;
	      density = linear_step(0.7 - clouds_cirrus_coverage, 1.0, density);

	float detail_amplitude = 0.2;
	float detail_frequency = 0.00002;
	float curl_strength    = 0.1 * CLOUDS_CIRRUS_CURL_STRENGTH;

	for (int i = 0; i < 4; ++i) {
		float detail = texture(noisetex, coord * detail_frequency + curl * curl_strength).x;

		density -= detail * detail_amplitude;

		detail_amplitude *= 0.6;
		detail_frequency *= 2.0;
		curl_strength *= 4.0;

		coord += 0.3 * wind_velocity * world_age;
	}

	float height_shaping = 1.0 - abs(1.0 - 2.0 * altitude_fraction);
	density = mix(1.0, 0.75, day_factor) * cube(max0(density)) * sqr(height_shaping) * CLOUDS_CIRRUS_DENSITY;

	return density;
}

float clouds_cirrus_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither
) {
	const uint step_count      = CLOUDS_CIRRUS_LIGHTING_STEPS;
	const float max_ray_length = 1e3;
	const float step_growth    = 1.5;

	// Assuming ray_origin is between inner and outer boundary, find distance to closest layer
	// boundary
	vec2 inner_sphere = intersect_sphere(ray_origin, ray_dir, clouds_cirrus_radius - 0.5 * CLOUDS_CIRRUS_THICKNESS);
	vec2 outer_sphere = intersect_sphere(ray_origin, ray_dir, clouds_cirrus_radius + 0.5 * CLOUDS_CIRRUS_THICKNESS);
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
		float altitude_fraction = (r - clouds_cirrus_radius) * rcp(CLOUDS_CIRRUS_THICKNESS) + 0.5;

		vec3 sphere_pos = dithered_pos * (clouds_cirrus_radius / r);

		float cirrus, cirrocumulus;
		optical_depth += clouds_cirrus_density(sphere_pos.xz, altitude_fraction, cirrus, cirrocumulus) * ray_step.w;
	}

	return optical_depth;
}

vec2 clouds_cirrus_scattering(
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

	float scatter_amount = clouds_cirrus_scattering_coeff;
	float extinct_amount = clouds_cirrus_extinction_coeff * (1.0 + 0.5 * max0(smoothstep(0.0, 0.15, abs(sun_dir.y)) - smoothstep(0.5, 0.7, clouds_cirrus_coverage)));

	for (uint i = 0u; i < 4u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount * light_optical_depth) * phase * powder_effect; // direct light
		scattering.y += scatter_amount * exp(-0.33 * CLOUDS_CIRRUS_THICKNESS * extinct_amount * density) * isotropic_phase; // sky light

		scatter_amount *= 0.5;
		extinct_amount *= 0.5;
		phase_g *= 0.8;

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	float scattering_integral = (1.0 - view_transmittance) / clouds_cirrus_extinction_coeff;
	return scattering * scattering_integral;
}

CloudsResult draw_cirrus_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	// ---------------
	//   Ray Casting
	// ---------------

	float r = length(air_viewer_pos);

	vec2 dists = intersect_sphere(air_viewer_pos, ray_dir, clouds_cirrus_radius);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;
	bool terrain_intersected = distance_to_terrain >= 0.0 && r < clouds_cirrus_radius && distance_to_terrain * CLOUDS_SCALE < dists.y;

	if (dists.y < 0.0                              // sphere not intersected
	 || planet_intersected && r < clouds_cirrus_radius // planet blocking clouds
	 || terrain_intersected
	) { return clouds_not_hit; }

	float distance_to_sphere = (r < clouds_cirrus_radius) ? dists.y : dists.x;
	vec3 sphere_pos = air_viewer_pos + ray_dir * distance_to_sphere;

	// ------------------
	//   Cloud Lighting
	// ------------------

	bool moonlit = sun_dir.y < -0.049;
	vec3 light_dir = moonlit ? moon_dir : sun_dir;
	float cos_theta = dot(ray_dir, light_dir);

	float cirrus, cirrocumulus;
	float density = clouds_cirrus_density(sphere_pos.xz, 0.5, cirrus, cirrocumulus);
	if (density < eps) return clouds_not_hit;

	float light_optical_depth = clouds_cirrus_optical_depth(sphere_pos, light_dir, dither);
	float view_optical_depth  = density * clouds_cirrus_extinction_coeff * CLOUDS_CIRRUS_THICKNESS * rcp(abs(ray_dir.y) + eps);
	float view_transmittance  = exp(-view_optical_depth);

	vec2 scattering = clouds_cirrus_scattering(density, view_transmittance, light_optical_depth, cos_theta);

	// Get main light color for this layer
	float r_sq = dot(sphere_pos, sphere_pos);
	float rcp_r = inversesqrt(r_sq);
	float mu = dot(sphere_pos, light_dir) * rcp_r;
	float rr = r_sq * rcp_r - 1500.0 * clamp01(linear_step(0.0, 0.05, cirrocumulus) * (1.0 - linear_step(0.0, 0.1, cirrus)) + cirrocumulus);

	vec3 light_color  = sunlight_color * atmosphere_transmittance(mu, rr);
		 light_color  = atmosphere_post_processing(light_color);
	     light_color *= moonlit ? moon_color : sun_color;
		 light_color *= 1.0 - rainStrength;

	// Remap the transmittance so that min_transmittance is 0
	vec3 clouds_scattering = scattering.x * light_color + scattering.y * sky_color;
	     clouds_scattering = clouds_aerial_perspective(clouds_scattering, view_transmittance, air_viewer_pos, sphere_pos, ray_dir, clear_sky);

	return CloudsResult(
		clouds_scattering,
		view_transmittance,
		distance_to_sphere
	);
}
#endif

CloudsResult blend_layers(CloudsResult old, CloudsResult new) {
	bool new_in_front = new.apparent_distance < old.apparent_distance;

	vec3 scattering_behind       = new_in_front ? old.scattering : new.scattering;
	vec3 scattering_in_front     = new_in_front ? new.scattering : old.scattering;
	float transmittance_in_front = new_in_front ? new.transmittance : old.transmittance;

	return CloudsResult(
		scattering_in_front + transmittance_in_front * scattering_behind,
		old.transmittance * new.transmittance,
		min(old.apparent_distance, new.apparent_distance)
	);
}

CloudsResult draw_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	CloudsResult result = clouds_not_hit;
	float r = length(air_viewer_pos);

	if (clouds_cumulus_congestus_amount < 0.5) {
		#ifdef CLOUDS_CUMULUS
		result = draw_cumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
		if (result.transmittance < 1e-3 && r < clouds_cumulus_radius) return result;
		#endif
	} else {
		#ifdef CLOUDS_CUMULUS_CONGESTUS
		result = draw_cumulus_congestus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
		if (result.transmittance < 1e-3) return result; // Always show cumulus congestus on top
		#endif
	}

#ifdef CLOUDS_ALTOCUMULUS
	CloudsResult result_ac = draw_altocumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ac);
	if (result.transmittance < 1e-3 && r < clouds_altocumulus_radius) return result;
#endif

#ifdef CLOUDS_CIRRUS
	CloudsResult result_ci = draw_cirrus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ci);
#endif

	return result;
}

#if defined PROGRAM_PREPARE && defined CLOUD_SHADOWS
#include "/include/light/cloud_shadows.glsl"

float render_cloud_shadow_map(vec2 uv) {
	// Transform position from scene-space to clouds-space
	vec3 ray_origin = unproject_cloud_shadow_map(uv);
	     ray_origin = vec3(ray_origin.xz, ray_origin.y + eyeAltitude - SEA_LEVEL).xzy * CLOUDS_SCALE + vec3(0.0, planet_radius, 0.0);

	vec3 pos; float t, density, extinction_coeff;
	float shadow = 1.0;

#ifdef CLOUDS_CUMULUS
	float dynamic_thickness  = mix(0.5, 1.0, smoothstep(0.4, 0.6, clouds_cumulus_coverage.y));
	vec2  detail_weights     = mix(vec2(0.33, 0.40), vec2(0.25, 0.20), sqr(clouds_stratus_amount)) * CLOUDS_CUMULUS_DETAIL_STRENGTH;
	vec2  edge_sharpening    = mix(vec2(3.0, 8.0), vec2(1.0, 2.0), clouds_stratus_amount);

	extinction_coeff = 0.25 * mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y))) * (1.0 - 0.33 * rainStrength) * CLOUDS_CUMULUS_DENSITY;
	t = intersect_sphere(ray_origin, light_dir,	clouds_cumulus_radius + 0.25 * clouds_cumulus_thickness).y;
	pos = ray_origin + light_dir * t;
	density = clouds_cumulus_density(pos, detail_weights, edge_sharpening, dynamic_thickness);
	shadow *= exp(-0.50 * extinction_coeff * clouds_cumulus_thickness * rcp(abs(light_dir.y) + eps) * density);
#endif

#ifdef CLOUDS_ALTOCUMULUS
	extinction_coeff = mix(0.05, 0.1, day_factor) * CLOUDS_ALTOCUMULUS_DENSITY * (1.0 - 0.33 * rainStrength);
	t = intersect_sphere(ray_origin, light_dir,	clouds_altocumulus_radius + 0.5 * clouds_altocumulus_thickness).y;
	pos = ray_origin + light_dir * t;
	density = clouds_altocumulus_density(pos);
	shadow *= exp(-0.50 * extinction_coeff * clouds_altocumulus_thickness * rcp(abs(light_dir.y) + eps) * density);
#endif

#ifdef CLOUDS_CIRRUS
	float cirrus, cirrocumulus;
	t = intersect_sphere(ray_origin, light_dir,	clouds_cirrus_radius).y;
	pos = ray_origin + light_dir * t;
	density = clouds_cirrus_density(pos.xz, 0.5, cirrus, cirrocumulus);
	shadow *= exp(-0.25 * clouds_cirrus_extinction_coeff * clouds_cirrus_thickness * rcp(abs(light_dir.y) + eps) * density) * 0.5 + 0.5;
#endif

	return shadow;
}
#endif

#endif // INCLUDE_SKY_CLOUDS
