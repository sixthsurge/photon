#if !defined INCLUDE_LIGHTING_LIGHTING
#define INCLUDE_LIGHTING_LIGHTING

#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/fastMath.glsl"

const float skylightBoost       = 1.0;
const float blocklightIntensity = 40.0 * BLOCKLIGHT_INTENSITY;
const float emissionIntensity   = 16.0 * BLOCKLIGHT_INTENSITY;
const float sssIntensity        = 3.0;
const float sssDensity          = 12.0;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = normalizeSafe(albedo) * sqrt(sqrt(length(albedo)));
	     coeff = (sssDensity * coeff - sssDensity) / sssAmount;

	vec3 sss1 = exp(3.0 * coeff * sssDepth) * henyeyGreensteinPhase(-LoV, 0.5);
	vec3 sss2 = exp(1.0 * coeff * sssDepth) * (0.6 * henyeyGreensteinPhase(-LoV, 0.4) + 0.4 * henyeyGreensteinPhase(-LoV, -0.2));

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

float getFakeBouncedLight() {
	return 0.0;
}

vec3 getSceneLighting(
	Material material,
	vec3 scenePos,
	vec3 normal,
	vec3 geometryNormal,
	vec3 viewerDir,
	vec3 ambientIrradiance,
	vec3 directIrradiance,
	vec3 skylight,
	vec2 lmCoord,
	float ao,
	uint blockId
) {
	vec3 radiance = material.emission * emissionIntensity;

	// Sunlight/moonlight

#if defined WORLD_OVERWORLD || defined WORLD_END
	float NoL = dot(normal, lightDir) * step(0.0, dot(geometryNormal, lightDir));

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
	float cloudShadow = getCloudShadows(colortex7, scenePos);
#else
	float cloudShadow = 1.0;
#endif

	float distanceTraveled;
	vec3 visibility = NoL * getShadows(scenePos, geometryNormal, NoL, lmCoord.y, cloudShadow, material.sssAmount, blockId, distanceTraveled);

	if (maxOf(visibility) > eps || material.sssAmount > eps) {
		float NoV = clamp01(dot(normal, viewerDir));
		float LoV = dot(lightDir, viewerDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		vec3 diffuse = diffuseHammon(material, NoL, NoV, NoH, LoV);
		vec3 specular = getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH);
		vec3 subsurface = getSubsurfaceScattering(material.albedo, material.sssAmount, distanceTraveled, LoV);

		radiance += directIrradiance * ((diffuse + specular) * visibility + subsurface) * getCloudShadows(colortex7, scenePos);
	}

	//radiance += getFakeBouncedLight();
#endif

	// Blocklight

	vec3 bsdf = material.albedo * rcpPi;

	vec3 blocklightColor = blackbody(BLOCKLIGHT_TEMPERATURE);
	float blocklightFalloff = getBlocklightFalloff(lmCoord.x, ao);

	radiance += blocklightIntensity * blocklightColor * blocklightFalloff * bsdf;

	// Skylight

	float skylightFalloff = getSkylightFalloff(lmCoord.y);

	radiance += skylight * skylightFalloff * skylightBoost * bsdf;

	// Ambient light

	radiance += ambientIrradiance * bsdf;

	return radiance;
}

#endif // INCLUDE_LIGHTING_LIGHTING
