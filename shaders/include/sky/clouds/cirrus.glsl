#if !defined INCLUDE_SKY_CLOUDS_CIRRUS
#define INCLUDE_SKY_CLOUDS_CIRRUS

// 3rd layer: planar cirrus/cirrocumulus clouds

#include "common.glsl"

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

float clouds_cirrus_density(
	vec2 coord,
	float altitude_fraction
) {
	const float wind_angle = CLOUDS_CIRRUS_WIND_ANGLE * degree;
	const vec2 wind_velocity = CLOUDS_CIRRUS_WIND_SPEED * vec2(cos(wind_angle), sin(wind_angle));

	coord = coord + cameraPosition.xz * CLOUDS_SCALE;
	coord = coord + wind_velocity * world_age;

	vec2 curl = curl2D(0.00002 * coord) * 0.5
	          + curl2D(0.00004 * coord) * 0.25
			  + curl2D(0.00008 * coord) * 0.125;

	float height_shaping = 1.0 - abs(1.0 - 2.0 * altitude_fraction);

	// Cirrus 

	float density_cirrus = 0.7 * texture(noisetex, (0.000001 / CLOUDS_CIRRUS_SIZE) * coord + (0.004 * CLOUDS_CIRRUS_CURL_STRENGTH) * curl).x
	                     + 0.3 * texture(noisetex, (0.000008 / CLOUDS_CIRRUS_SIZE) * coord + (0.008 * CLOUDS_CIRRUS_CURL_STRENGTH) * curl).x;
	density_cirrus = linear_step(
		0.7 - daily_weather_variation.clouds_cirrus_coverage.x, 
		1.0, 
		density_cirrus
	);

	vec2 detail_coord = coord;

	float detail_amplitude = 0.2;
	float detail_frequency = 0.00002;
	float curl_strength    = 0.1 * CLOUDS_CIRRUS_CURL_STRENGTH;

	for (int i = 0; i < 4; ++i) {
		float detail = texture(noisetex, detail_coord * detail_frequency + curl * curl_strength).x;

		density_cirrus -= detail * detail_amplitude;

		detail_amplitude *= 0.6;
		detail_frequency *= 2.0;
		curl_strength *= 4.0;

		detail_coord += 0.3 * wind_velocity * world_age;
	}

	density_cirrus = mix(1.0, 0.75, day_factor) * cube(max0(density_cirrus)) * sqr(height_shaping) * CLOUDS_CIRRUS_DENSITY;

	// Cirrocumulus 

	float coverage = texture(noisetex, (0.0000026 / CLOUDS_CIRROCUMULUS_SIZE) * coord + 0.25).w;
	coverage = 5.0 * linear_step(
		0.25, 
		0.9, 
		daily_weather_variation.clouds_cirrus_coverage.y * coverage
	);

	float density_cirrocumulus = dampen(texture(noisetex, (0.000025 * rcp(CLOUDS_CIRROCUMULUS_SIZE)) * coord + (0.033 * CLOUDS_CIRROCUMULUS_CURL_STRENGTH) * curl).w);
	density_cirrocumulus = linear_step(1.0 - coverage, 1.0, density_cirrocumulus);

	vec2 curl_cc = curl2D(0.001 * coord);

	density_cirrocumulus -= sqr(texture(noisetex, coord * 0.00005 + (0.003 * CLOUDS_CIRROCUMULUS_CURL_STRENGTH) * curl_cc).y) * (CLOUDS_CIRROCUMULUS_DETAIL_STRENGTH * 1.0);
	density_cirrocumulus -= sqr(texture(noisetex, coord * 0.0002 + (0.007 * CLOUDS_CIRROCUMULUS_CURL_STRENGTH) * curl_cc).y) * (CLOUDS_CIRROCUMULUS_DETAIL_STRENGTH * 0.5);
	density_cirrocumulus -= sqr(texture(noisetex, coord * 0.0008 + (0.03 * CLOUDS_CIRROCUMULUS_CURL_STRENGTH) * curl_cc).y) * (CLOUDS_CIRROCUMULUS_DETAIL_STRENGTH * 0.1);

	density_cirrocumulus  = max0(density_cirrocumulus);

	density_cirrocumulus = 0.25 * pow4(max0(density_cirrocumulus)) * height_shaping * CLOUDS_CIRROCUMULUS_DENSITY;

	return density_cirrus + density_cirrocumulus;
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
		if (clamp01(altitude_fraction) != altitude_fraction) continue;

		vec3 sphere_pos = dithered_pos * (clouds_cirrus_radius / r);

		optical_depth += clouds_cirrus_density(sphere_pos.xz, altitude_fraction) * ray_step.w;
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
	vec3 phase_g = vec3(0.6, 0.9, 0.3);

	float powder_effect = 4.0 * (1.0 - exp(-40.0 * density));
	      powder_effect = mix(powder_effect, 1.0, pow1d5(cos_theta * 0.5 + 0.5));

	float scatter_amount = clouds_cirrus_scattering_coeff;
	float extinct_amount = clouds_cirrus_extinction_coeff * (1.0 + 0.5 * max0(smoothstep(0.0, 0.15, abs(sun_dir.y)) - smoothstep(0.5, 0.7, daily_weather_variation.clouds_cirrus_coverage.x)));

	for (uint i = 0u; i < 4u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount * light_optical_depth) * phase * powder_effect; // direct light
		scattering.y += scatter_amount * exp(-0.33 * CLOUDS_CIRRUS_THICKNESS * extinct_amount * density) * isotropic_phase; // sky light

		scatter_amount *= 0.5;
		extinct_amount *= 0.25;
		phase_g *= 0.5;

		powder_effect = mix(powder_effect, sqrt(powder_effect), 0.5);

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

	if (dists.y < 0.0                                  // sphere not intersected
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

	float density = clouds_cirrus_density(sphere_pos.xz, 0.5);
	if (density < eps) return clouds_not_hit;

	float light_optical_depth = clouds_cirrus_optical_depth(sphere_pos, light_dir, dither);
	float view_optical_depth  = 0.5 * density * clouds_cirrus_extinction_coeff * CLOUDS_CIRRUS_THICKNESS * rcp(abs(ray_dir.y) + eps);
	float view_transmittance  = exp(-view_optical_depth);

	vec2 scattering = clouds_cirrus_scattering(density, view_transmittance, light_optical_depth, cos_theta);

	// Get main light color for this layer
	float r_sq = dot(sphere_pos, sphere_pos);
	float rcp_r = inversesqrt(r_sq);
	float mu = dot(sphere_pos, light_dir) * rcp_r;

	vec3 light_color  = sunlight_color * atmosphere_transmittance(sphere_pos, light_dir);
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
