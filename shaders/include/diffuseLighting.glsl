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

const float blocklightIntensity = 8.0;
const float emissionIntensity   = 32.0;
const float sssIntensity        = 0.85;
const float sssDensity          = 32.0;
const float metalDiffuseAmount  = 0.25; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR
const vec3  blocklightColor     = toRec2020(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = albedo * inversesqrt(getLuminance(albedo) + eps);
	     coeff = clamp01(0.75 * coeff);
	     coeff = (1.0 - coeff) * sssDensity / sssAmount;

	return exp2(-coeff * sssDepth) * sssIntensity * dampen(sssAmount);
}

vec3 getSceneLighting(
	Material material,
	vec3 normal,
	vec3 flatNormal,
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
	vec3 lighting = vec3(0.0);

	float directionalShading = (0.9 + 0.1 * normal.x) * (0.8 + 0.2 * abs(flatNormal.y)); // Arbitrary directional shading to make faces easier to distinguish

	// Sunlight/moonlight

	float diffuse = lift(max0(NoL), 1.4) * (1.0 - 0.5 * material.sssAmount) * directionalShading;
	vec3 bounced = 0.05 * (1.0 - shadows * max0(NoL)) * (1.0 - 0.33 * max0(normal.y)) * pow1d5(ao + eps) * pow4(lmCoord.y);
	vec3 sss = getSubsurfaceScattering(material.albedo, material.sssAmount, sssDepth, LoV);

	lighting += lightColor * (diffuse * shadows * ao + bounced + sss);

	// Skylight

#if defined SH_SKYLIGHT && defined PROGRAM_DEFERRED3
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, ao);
#else
	vec3 skylight = skyColor * ao;
#endif

	float skylightFalloff = sqr(lmCoord.y);

	lighting += skylight * skylightFalloff;

	// Blocklight

	// Reduce blocklight intensity in daylight
	float blocklightScale = 1.0 - 0.5 * timeNoon * lmCoord.y;

	float blocklightFalloff  = clamp01(pow12(lmCoord.x) + 0.27 * pow5(lmCoord.x) + 0.18 * sqr(lmCoord.x) + 0.08 * lmCoord.x);
	      blocklightFalloff *= mix(ao, 1.0, blocklightFalloff) * directionalShading;

	lighting += blocklightIntensity * blocklightScale * blocklightFalloff * blocklightColor;

	lighting += emissionIntensity * blocklightScale * material.albedo * material.emission;

	// Cave lighting

	lighting += CAVE_LIGHTING_I * ao * directionalShading * (1.0 - skylightFalloff);

	return max0(lighting) * material.albedo * rcpPi * mix(1.0, metalDiffuseAmount, float(material.isMetal));
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // DIFFUSELIGHTING_INCLUDED
