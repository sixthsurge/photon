#if !defined WATER_FOG_INCLUDED
#define WATER_FOG_INCLUDED

#include "phase_functions.glsl"
#include "utility/color.glsl"

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

mat2x3 get_simple_water_fog(
	float dist,
	float lov,
	float sss_depth,
	float skylight
) {
	// multiple scattering approximation from Jessie
	const vec3 scattering_albedo = water_scattering_coeff / water_extinction_coeff;
	const vec3 multiple_scattering_factor = 0.84 * scattering_albedo;
	const vec3 multiple_scattering_energy = multiple_scattering_factor / (1.0 - multiple_scattering_factor);

	vec3 transmittance = exp(-water_extinction_coeff * dist);

	vec3 scattering  = light_color * exp(-water_extinction_coeff * sss_depth) * smoothstep(0.0, 0.25, skylight); // direct lighting
		 scattering *= 0.7 * henyey_greenstein_phase(lov, 0.4) + 0.3 * isotropic_phase;                          // phase function for direct lighting
	     scattering += sky_samples[0] * pow4(skylight) * isotropic_phase;                                        // ambient lighting
	     scattering *= (1.0 - transmittance) * water_scattering_coeff / water_extinction_coeff;                  // scattering integral
		 scattering *= 1.0 + multiple_scattering_energy;                                                         // multiple scattering

	return mat2x3(scattering, transmittance);
}

#endif // WATER_FOG_INCLUDED
