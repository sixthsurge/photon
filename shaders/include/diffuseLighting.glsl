#if !defined DIFFUSELIGHTING_INCLUDED
#define DIFFUSELIGHTING_INCLUDED

#include "bsdf.glsl"
#include "material.glsl"
#include "palette.glsl"
#include "phaseFunctions.glsl"
#include "utility/fastMath.glsl"
#include "utility/sphericalHarmonics.glsl"

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

const float blocklightIntensity = 5.0;
const float emissionIntensity   = 32.0;
const float sssIntensity        = 5.0;
const float sssDensity          = 32.0;
const float metalDiffuseAmount  = 0.25; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR
const vec3  blocklightColor     = toRec2020(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = albedo * inversesqrt(getLuminance(albedo) + eps);
	     coeff = clamp01(0.75 * coeff);
	     coeff = (1.0 - coeff) * sssDensity / sssAmount;

	float phase = bilambertianPlatePhase(-LoV, 0.3);

	return pi * phase * exp2(-coeff * sssDepth) * sssIntensity * sqrt(sssAmount);
}

vec3 getSceneLighting(
	Material material,
	vec3 normal,
	vec3 bentNormal,
	vec3 shadows,
	vec2 lmCoord,
	float ao,
	float sssDepth,
	float NoL,
	float NoV,
	float NoH,
	float LoV
) {
	vec3 illuminance = vec3(0.0);

	// Sunlight/moonlight

	vec3 diffuse = diffuseHammon(material.albedo, material.roughness, material.refractiveIndex, material.f0.x, NoL, NoV, NoH, LoV) * (1.0 - 0.5 * material.sssAmount) * pi;
	vec3 bounced = 0.066 * (1.0 - shadows * max0(NoL)) * (1.0 - 0.33 * max0(normal.y)) * pow1d5(ao + eps) * pow4(lmCoord.y);
	vec3 sss = getSubsurfaceScattering(material.albedo, material.sssAmount, sssDepth, LoV);

	illuminance += lightColor * (max0(NoL) * diffuse * shadows * ao + bounced + sss);

	// Skylight

#if defined SH_SKYLIGHT && defined PROGRAM_DEFERRED3
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, ao);
#else
	vec3 skylight = skyColor * ao;
#endif

	float skylightFalloff = sqr(lmCoord.y);

	illuminance += skylight * skylightFalloff;

	// Blocklight

	float blocklightScale = 1.0 - 0.5 * timeNoon * lmCoord.y;

	float blocklightFalloff  = clamp01(1.2 * pow12(lmCoord.x) + 0.2 * pow5(lmCoord.x) + 0.1 * sqr(lmCoord.x) + 0.07 * lmCoord.x);
	      blocklightFalloff *= mix(ao, 1.0, blocklightFalloff);

	illuminance += blocklightIntensity * blocklightScale * blocklightFalloff * blocklightColor;

	illuminance += emissionIntensity * blocklightScale * material.albedo * material.emission;

	// Cave lighting

	illuminance += CAVE_LIGHTING_I * ao * (1.0 - skylightFalloff);

	return max0(illuminance) * material.albedo * rcpPi * mix(1.0, metalDiffuseAmount, float(material.isMetal));
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // DIFFUSELIGHTING_INCLUDED
