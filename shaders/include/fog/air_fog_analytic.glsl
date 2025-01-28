#if !defined INCLUDE_FOG_AIR_FOG_ANALYTIC
#define INCLUDE_FOG_AIR_FOG_ANALYTIC

#include "/include/fog/air_fog_vl.glsl"
	
vec2 air_fog_analytic_airmass(vec3 ray_origin_world, vec3 ray_direction_world, float ray_length) {
	// Integral of density function with respect to t

	const vec2 mul = -rcp(air_fog_falloff_half_life);
	const vec2 add = -mul * air_fog_falloff_start;

	vec2 a = ray_origin_world.y * mul + add;
	vec2 p1 = exp2(ray_length * ray_direction_world.y * mul + a);
	vec2 p2 = exp2(a);

	return clamp(
		(p1 - p2) * rcp(log(2.0) * mul * ray_direction_world.y),
		0.0,
		ray_length
	) * (0.5 * OVERWORLD_FOG_INTENSITY);
}

mat2x3 air_fog_analytic(vec3 ray_origin_world, vec3 ray_end_world, bool sky, float skylight) {
	vec3 ray_direction_world; float ray_length;
	length_normalize(ray_end_world - ray_origin_world, ray_direction_world, ray_length);
	ray_length = sky ? 4096.0 : ray_length;

	vec2 airmass = air_fog_analytic_airmass(
		ray_origin_world, 
		ray_direction_world,
		ray_length 
	);
	vec3 optical_depth = air_fog_coeff[1] * airmass;
	vec3 transmittance = exp(-optical_depth);
	vec3 scattering_integral = (1.0 - transmittance) / max(optical_depth, eps);

	vec3 rayleigh_scattering = scattering_integral * airmass.x * air_fog_coeff[0][0];
	vec3 mie_scattering = scattering_integral * airmass.y * air_fog_coeff[0][1];

	float LoV = dot(ray_direction_world, light_dir);
	float mie_phase = 0.7 * henyey_greenstein_phase(LoV, 0.5) + 0.3 * henyey_greenstein_phase(LoV, -0.2);

	/*
	// Single scattering
	vec3 scattering  = light_color * (light_sun * vec2(isotropic_phase, mie_phase));
	     scattering += ambient_color * (light_sky * vec2(isotropic_phase));
	/*/
	// Multiple scattering
	vec3 scattering = vec3(0.0);
	float scatter_amount = 1.0;
	float anisotropy = 1.0;

	scattering += 2.0 * (rayleigh_scattering + mie_scattering) * isotropic_phase * ambient_color;

	for (int i = 0; i < 4; ++i) {
		float mie_phase = 0.7 * henyey_greenstein_phase(LoV, 0.5 * anisotropy) + 0.3 * henyey_greenstein_phase(LoV, -0.2 * anisotropy);

		scattering += scatter_amount * (rayleigh_scattering * isotropic_phase + mie_scattering * mie_phase) * light_color;

		scatter_amount *= 0.5;
		mie_phase = 0.7 * henyey_greenstein_phase(LoV, 0.5) + 0.3 * isotropic_phase;
		anisotropy *= 0.7;
	}
	//*/

	scattering *= max(skylight, eye_skylight);
	scattering *= 1.0 - blindness;

	// Artifically brighten fog in the early morning and evening (looks nice)
	float evening_glow = 0.75 * linear_step(0.05, 1.0, exp(-300.0 * sqr(sun_dir.y + 0.02)));
	scattering += scattering * evening_glow;

	return mat2x3(max0(scattering), max0(transmittance));
}

#endif // INCLUDE_FOG_AIR_FOG_ANALYTIC

