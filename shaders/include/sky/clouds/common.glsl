#if !defined INCLUDE_SKY_CLOUDS_COMMON
#define INCLUDE_SKY_CLOUDS_COMMON

#include "/include/sky/atmosphere.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

uniform float day_factor;

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

// ----

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

#endif
