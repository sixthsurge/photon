#if !defined INCLUDE_FOG_AIR_FOG_ANALYTIC
#define INCLUDE_FOG_AIR_FOG_ANALYTIC

#include "/include/fog/overworld/constants.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/utility/phase_functions.glsl"
	
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

mat2x3 air_fog_analytic(vec3 ray_origin_world, vec3 ray_end_world, bool sky, float skylight, float shadow) {
#ifdef DISTANT_HORIZONS
    float fog_end = float(dhRenderDistance);
#else
    float fog_end = far;
#endif

	vec3 ray_direction_world; float ray_length;
	length_normalize(ray_end_world - ray_origin_world, ray_direction_world, ray_length);
	ray_length = sky ? fog_end : ray_length;

	vec2 airmass = air_fog_analytic_airmass(
		ray_origin_world, 
		ray_direction_world,
		ray_length 
	);
	vec3 optical_depth = fog_params.rayleigh_scattering_coeff * airmass.x 
		+ fog_params.mie_extinction_coeff * airmass.y;
	vec3 transmittance = exp(-optical_depth);
	vec3 scattering_integral = (1.0 - transmittance) / max(optical_depth, eps);

	vec3 rayleigh_scattering = scattering_integral * airmass.x * fog_params.rayleigh_scattering_coeff;
	vec3 mie_scattering = scattering_integral * airmass.y * fog_params.mie_scattering_coeff;

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

		scattering += scatter_amount * (rayleigh_scattering * isotropic_phase + mie_scattering * mie_phase) * light_color * (1.0 - 0.9 * rainStrength) * shadow;

		scatter_amount *= 0.5;
		anisotropy *= 0.7;
	}
	//*/

	scattering *= max(skylight, eye_skylight);
	scattering *= clamp01(1.0 - blindness - darknessFactor);

	// Artifically brighten fog in the early morning and evening (looks nice)
	float evening_glow = 0.75 * linear_step(0.05, 1.0, exp(-300.0 * sqr(sun_dir.y + 0.02)));
	scattering += scattering * evening_glow;

	return mat2x3(max0(scattering), max0(transmittance));
}

#endif // INCLUDE_FOG_AIR_FOG_ANALYTIC
