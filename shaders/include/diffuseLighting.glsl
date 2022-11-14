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

const float blocklightIntensity = 12.0;
const float emissionIntensity   = 50.0;
const float sssIntensity        = 4.0;
const float sheenIntensity      = 0.5;
const float sssDensity          = 32.0;
const float metalDiffuseAmount  = 0.25; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR
const vec3  blocklightColor     = toRec2020(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sheenAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = albedo * inversesqrt(getLuminance(albedo) + eps);
	     coeff = clamp01(0.75 * coeff);
	     coeff = (1.0 - coeff) * sssDensity / sssAmount;

	float phase = mix(isotropicPhase, henyeyGreensteinPhase(-LoV, 0.7), 0.33);

	vec3 sss = sssIntensity * phase * exp2(-coeff * sssDepth) * dampen(sssAmount) * pi;
	vec3 sheen = sheenIntensity * rcp(albedo + eps) * exp2(-0.5 * coeff * sssDepth) * henyeyGreensteinPhase(-LoV, 0.8);

	return sss + sheen * sheenAmount;
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

	// Sunlight/moonlight

	float diffuse = lift(max0(NoL), 0.33) * (1.0 - 0.5 * material.sssAmount) * dampen(ao) * mix(ao * ao, 1.0, NoL * NoL);
	vec3 bounced = 0.044 * (1.0 - shadows * max0(NoL)) * (1.0 - 0.33 * max0(normal.y)) * pow1d5(ao + eps) * pow4(lmCoord.y);
	vec3 sss = getSubsurfaceScattering(material.albedo, material.sssAmount, material.sheenAmount, sssDepth, LoV);

	lighting += lightColor * (diffuse * shadows + bounced + sss);

	// Skylight

#ifdef SH_SKYLIGHT
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, ao);
#else
	vec3 horizonColor = mix(skyColors[1], skyColors[2], dot(bentNormal.xz, moonDir.xz) * 0.5 + 0.5);
	     horizonColor = mix(horizonColor, mix(skyColors[1], skyColors[2], step(sunDir.y, 0.5)), abs(bentNormal.y) * (timeNoon + timeMidnight));

	float horizonWeight = 0.166 * (timeNoon + timeMidnight) + 0.03 * (timeSunrise + timeSunset);

	vec3 skylight  = mix(skyColors[0] * 1.3, horizonColor, horizonWeight);
	     skylight  = mix(horizonColor * 0.2, skylight, clamp01(abs(bentNormal.y)) * 0.3 + 0.7);
	     skylight *= 1.0 - 0.75 * clamp01(-bentNormal.y);
		 skylight *= 1.0 + 0.2 * clamp01(flatNormal.y) * (1.0 - shadows.x) * (timeNoon + timeMidnight);
	     skylight *= ao * pi;
#endif

	float skylightFalloff = sqr(lmCoord.y);

	lighting += skylight * skylightFalloff;

	// Blocklight

	float directionalShading = (0.9 + 0.1 * normal.x) * (0.8 + 0.2 * abs(flatNormal.y)); // Random directional shading to make faces easier to distinguish

	float blocklightFalloff  = 0.20 * pow5(lmCoord.x) + 0.08 * sqr(lmCoord.x) + 0.055 * lmCoord.x; // Base falloff
	      blocklightFalloff *= mix(ao, 1.0, clamp01(blocklightFalloff * 2.0));                     // Stronger AO further from the light source
		  blocklightFalloff *= 1.0 - 0.33 * timeNoon * lmCoord.y;                                  // Reduce blocklight intensity in daylight
		  blocklightFalloff += 2.83 * pow16(lmCoord.x);                            // Strong highlight around the light source, visible even in the daylight

	lighting += (blocklightFalloff * directionalShading) * (blocklightIntensity * blocklightColor);

	lighting += material.emission * emissionIntensity;

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
