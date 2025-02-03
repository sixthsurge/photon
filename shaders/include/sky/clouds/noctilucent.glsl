#if !defined INCLUDE_SKY_CLOUDS_NOCTILUCENT
#define INCLUDE_SKY_CLOUDS_NOCTILUCENT

// 4th layer: Noctilucent clouds

#include "common.glsl"

float clouds_noctilucent_density(vec2 coord, vec3 ray_dir) {
	coord *= 0.25;

	vec2 curl = curl2D(0.00002 * coord) * 0.5
	          + curl2D(0.00004 * coord) * 0.25
			  + curl2D(0.00008 * coord) * 0.125;

	float density = dampen(texture(noisetex, 0.000001 * coord + 0.02 * curl).y);

	float detail_amplitude = 0.3;
	float detail_frequency = 0.00001;
	float curl_strength    = 0.05;

	for (int i = 0; i < 4; ++i) {
		float detail = texture(noisetex, coord * detail_frequency + curl * curl_strength).y;

		density += detail * detail_amplitude;

		detail_amplitude *= 0.5;
		detail_frequency *= 1.5;
		curl_strength    *= 4.0;
	}

	float highlight  = dampen(texture(noisetex, 0.000004 * coord + 0.02 * curl).y);
	      highlight -= (1.0 - texture(noisetex, 0.000014 * coord + 0.05 * curl).y) * 0.15;

	density += 2.0 * pow8(max0(highlight));

	return sqr(max0(density)) * clouds_params.noctilucent_amount;
}

vec4 draw_noctilucent_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky
) {
	const vec3  color            = 0.35 * vec3(1.5, 2.0, 9.0);
	const float phase_g          = 0.8;
	const float extinction_coeff = 0.001; 

	float visibility = pulse(sun_dir.y, -0.10, 0.1);

	if (visibility < eps || clouds_params.noctilucent_amount < eps) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}

	// ---------------
	//   Ray Casting
	// ---------------

	float r = length(air_viewer_pos);

	vec2 dists = intersect_sphere(air_viewer_pos, ray_dir, clouds_noctilucent_radius);
	bool planet_intersected = intersect_sphere(air_viewer_pos, ray_dir, min(r - 10.0, planet_radius)).y >= 0.0;

	if (dists.y < 0.0 // sphere not intersected
	 || planet_intersected && r < clouds_noctilucent_radius // planet blocking clouds
	) { return vec4(0.0, 0.0, 0.0, 1.0); }

	float distance_to_sphere = (r < clouds_cirrus_radius) ? dists.y : dists.x;
	vec3 sphere_pos = air_viewer_pos + ray_dir * distance_to_sphere;

	// ------------------
	//   Cloud Lighting
	// ------------------

	float density = clouds_noctilucent_density(sphere_pos.xz, ray_dir);
	float transmittance = exp(-extinction_coeff * density);

	float phase = henyey_greenstein_phase(dot(ray_dir, sun_dir), phase_g);
	vec3 scattering = visibility * color * density * phase;
	     scattering = clouds_aerial_perspective(scattering, transmittance, air_viewer_pos, sphere_pos, ray_dir, clear_sky);

	return vec4(scattering, transmittance);
}

#endif // INCLUDE_SKY_CLOUDS_NOCTILUCENT
