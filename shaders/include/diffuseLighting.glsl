#if !defined DIFFUSELIGHTING_INCLUDED
#define DIFFUSELIGHTING_INCLUDED

#include "utility/fastMath.glsl"
#include "utility/sphericalHarmonics.glsl"
#include "bsdf.glsl"
#include "material.glsl"
#include "palette.glsl"

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

const float blocklightIntensity = 12.0;
const float emissionIntensity   = 32.0;
const float sssIntensity        = 3.0;
const float sssDensity          = 12.0;
const float metalDiffuseAmount  = 0.25; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR
const vec3  blocklightColor     = toRec2020(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = normalizeSafe(albedo) * sqrt(sqrt(length(albedo)));
	     coeff = (clamp01(coeff) * sssDensity - sssDensity) / sssAmount;

	vec3 sss1 = exp(3.0 * coeff * sssDepth) * henyeyGreensteinPhase(-LoV, 0.4);
	vec3 sss2 = exp(0.0 * coeff * sssDepth) * (0.6 * henyeyGreensteinPhase(-LoV, 0.33) + 0.4 * henyeyGreensteinPhase(-LoV, -0.2));

	return albedo * sssIntensity * sssAmount * (sss2);
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
	vec3 bounced = 0.07 * (1.0 - shadows * max0(NoL)) * (1.0 - 0.33 * max0(normal.y)) * pow1d5(ao) * pow4(lmCoord.y);
	vec3 sss = vec3(0.0);

	illuminance += lightCol * (max0(NoL) * diffuse * shadows * ao + bounced + sss);

	illuminance += lightCol * exp((clamp01(material.albedo * inversesqrt(getLuminance(material.albedo)))- 1.0) * 32.0 * sssDepth) * 0.75 * sqrt(material.sssAmount);

	// Skylight

#ifdef SH_SKYLIGHT
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, ao);
#else
#endif

	float skylightFalloff = sqr(lmCoord.y);

	illuminance += skylight * skylightFalloff;

	// Blocklight

	float blocklightScale = 1.0 - 0.5 * timeNoon * lmCoord.y;

	float blocklightFalloff  = clamp01(pow16(lmCoord.x) + 0.15 * pow5(lmCoord.x) + 0.1 * sqr(lmCoord.x) + 0.025 * dampen(lmCoord.x));
	      blocklightFalloff *= mix(ao, 1.0, blocklightFalloff);

	illuminance += blocklightIntensity * blocklightScale * blocklightFalloff * blocklightColor;

	illuminance += emissionIntensity * blocklightScale * material.albedo * material.emission;

	// Cave lighting

	illuminance += CAVE_LIGHTING_I * ao * (1.0 - skylightFalloff);

	return illuminance * material.albedo * rcpPi * mix(1.0, metalDiffuseAmount, float(material.isMetal));
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // DIFFUSELIGHTING_INCLUDED
