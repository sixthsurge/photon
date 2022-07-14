#if !defined INCLUDE_FRAGMENT_WATERVOLUME
#define INCLUDE_FRAGMENT_WATERVOLUME

#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/fragment/aces/matrices.glsl"

const vec3 waterAbsorptionCoeff = (vec3(0.4, 0.14, 0.08) * r709ToAp1Unlit) * WATER_DENSITY * vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B);
const vec3 waterScatteringCoeff = (vec3(0.03) * r709ToAp1Unlit) * WATER_DENSITY * WATER_SCATTERING_COEFF;
const vec3 waterExtinctionCoeff = waterAbsorptionCoeff + waterAbsorptionCoeff;

mat2x3 getSimpleWaterVolume(
	vec3 directIrradiance,
	vec3 skyIrradiance,
	vec3 ambientIrradiance,
	float distanceThroughWater,
	float LoV,
	float sssDepth,
	float skylight,
	float cloudShadow
) {
	// Multiple scattering approximation from Jessie, which is originally by Zombye
	const vec3 scatteringAlbedo = waterScatteringCoeff / waterExtinctionCoeff;
	const vec3 multipleScatteringFactor = 0.84 * scatteringAlbedo;
	const vec3 multipleScatteringEnergy = multipleScatteringFactor / (1.0 - multipleScatteringFactor);

	vec3 transmittance = exp(-waterExtinctionCoeff * distanceThroughWater);

	vec3 scattering  = directIrradiance * exp(-waterExtinctionCoeff * sssDepth) * smoothstep(0.0, 0.25, skylight) * cloudShadow;
	     scattering += (skyIrradiance * pow4(skylight) + ambientIrradiance) * isotropicPhase;
	     scattering *= (1.0 - transmittance) * waterScatteringCoeff / waterExtinctionCoeff;
		 scattering *= 0.7 * henyeyGreensteinPhase(-LoV, 0.4) + 0.3 * isotropicPhase;
		 scattering *= 1.0 + multipleScatteringEnergy;
		 scattering *= 1.0 - blindness;

	return mat2x3(scattering, transmittance);
}

#endif // INCLUDE_FRAGMENT_WATERVOLUME
