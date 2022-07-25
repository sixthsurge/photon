#if !defined INCLUDE_LIGHTING_LIGHTING
#define INCLUDE_LIGHTING_LIGHTING

#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/fastMath.glsl"

const float skylightBoost       = 1.0;
const float blocklightIntensity = 64.0 * BLOCKLIGHT_INTENSITY;
const float emissionIntensity   = 16.0 * BLOCKLIGHT_INTENSITY;
const float sssIntensity        = 3.0;
const float sssDensity          = 12.0;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = normalizeSafe(albedo) * sqrt(sqrt(length(albedo)));
	     coeff = (clamp01(coeff) * sssDensity - sssDensity) / sssAmount;

	vec3 sss1 = exp(3.0 * coeff * sssDepth) * henyeyGreensteinPhase(-LoV, 0.4);
	vec3 sss2 = exp(1.0 * coeff * sssDepth) * (0.6 * henyeyGreensteinPhase(-LoV, 0.33) + 0.4 * henyeyGreensteinPhase(-LoV, -0.2));

	return albedo * sssIntensity * sssAmount * (sss1 + sss2);
}

float getBlocklightFalloff(float blocklight, float ao) {
	float falloff  = rcp(sqr(16.0 - 15.0 * blocklight));
	      falloff  = linearStep(rcp(sqr(16.0)), 1.0, falloff);
	      falloff *= mix(ao, 1.0, falloff);

	return falloff;
}

float getSkylightFalloff(float skylight) {
	return pow4(skylight);
}

float getFakeBouncedLight(vec3 bentNormal, float sssDepth, float ao) {
	const float bounceAlbedo = 0.5;
	const float bounceBoost  = pi;
	const float bounceMul    = bounceAlbedo * bounceBoost * rcpPi;

	vec3 bounceDir = vec3(lightDir.xz, -lightDir.y).xzy;
	float bounce0 = clamp01(dot(bentNormal, bounceDir)) * (1.0 - exp2(-0.125 * sssDepth));
	float bounce1 = 0.33 * ao * clamp01(0.5 - 0.5 * bentNormal.y);

	return (bounceAlbedo * rcpPi) * (bounce0 + bounce1) * dampen(clamp01(lightDir.y + 0.15));
}

vec3 getSceneLighting(
	Material material,
	vec3 scenePos,
	vec3 normal,
	vec3 geometryNormal,
	vec3 viewerDir,
	vec3 directIrradiance,
#if defined PROGRAM_DEFERRED_LIGHTING && defined HBIL
	vec3 indirectIrradiance,
#else
	vec3 ambientIrradiance,
	vec3 skyIrradiance,
#endif
	vec2 lmCoord,
	float ao,
	uint blockId,
	out float sssDepth
) {
	ao = 1.0;
	vec3 radiance = material.emission * emissionIntensity;

	// Sunlight/moonlight

#if defined WORLD_OVERWORLD || defined WORLD_END
	float NoL = dot(normal, lightDir) * step(0.0, dot(geometryNormal, lightDir));

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
	float cloudShadow = getCloudShadows(colortex15, scenePos);
#else
	float cloudShadow = 1.0;
#endif

	vec3 visibility = NoL * calculateShadows(scenePos, geometryNormal, NoL, lmCoord.y, cloudShadow, blockId, sssDepth);

	if (maxOf(visibility) > eps || material.sssAmount > eps) {
		float NoV = clamp01(dot(normal, viewerDir));
		float LoV = dot(lightDir, viewerDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		vec3 diffuse = diffuseHammon(material, NoL, NoV, NoH, LoV) * (1.0 - 0.75 * material.sssAmount);
		vec3 specular = getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH);
		vec3 subsurface = getSubsurfaceScattering(material.albedo, material.sssAmount, sssDepth, LoV);

		radiance += directIrradiance * ((diffuse + specular) * visibility + subsurface) * getCloudShadows(colortex15, scenePos);
	}
#endif

	vec3 bsdf = material.albedo * rcpPi * float(!material.isMetal);

#if defined PROGRAM_DEFERRED_LIGHTING && defined HBIL
	// Indirect lighting already computed alongside HBIL
	radiance += indirectIrradiance * ao * bsdf;
#else

	// Blocklight

	vec3 blocklightColor = blackbody(BLOCKLIGHT_TEMPERATURE);
	float blocklightFalloff = getBlocklightFalloff(lmCoord.x, ao);
	radiance += blocklightIntensity * blocklightColor * blocklightFalloff * bsdf;

	// Skylight

	float skylightFalloff = getSkylightFalloff(lmCoord.y);
	radiance += skyIrradiance * skylightFalloff * skylightBoost * bsdf;

#if defined WORLD_OVERWORLD && defined FAKE_BOUNCED_SUNLIGHT && SHADOW_QUALITY == SHADOW_QUALITY_FANCY
	radiance += getFakeBouncedLight(normal, sssDepth, ao) * directIrradiance * bsdf * (skylightFalloff * skylightFalloff * cloudShadow);
#endif

	// Ambient light

	radiance += ambientIrradiance * ao * bsdf;
#endif

	return radiance;
}

#endif // INCLUDE_LIGHTING_LIGHTING
