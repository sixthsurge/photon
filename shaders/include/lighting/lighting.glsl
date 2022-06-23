#if !defined INCLUDE_LIGHTING_LIGHTING
#define INCLUDE_LIGHTING_LIGHTING

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	const float sssIntensity  = 3.0;
	const float sssDensity    = 12.0;

	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = normalizeSafe(albedo) * dampen(dampen(length(albedo)));
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

vec3 getSceneLighting(
	vec3 scenePos,
	vec3 normal,
	vec3 flatNormal,
	vec3 viewerDir,

) {
	vec3 radiance = vec3(0.0);

	// Sunlight/moonlight

	float distanceTraveled;
	vec3 visibility = NoL * getShadows(scenePos, flatNormal, NoL, lmCoord.y, cloudShadow, material.sssAmount, blockId, distanceTraveled);

	if (maxOf(visibility) > eps || material.sssAmount > eps) {
		float NoV = clamp01(dot(normal, -worldDir));
		float LoV = dot(lightDir, -worldDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		vec3 diffuse = diffuseHammon(material, NoL, NoV, NoH, LoV);
		vec3 specular = getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH, lightRadius);
		vec3 subsurface = getSubsurfaceScattering(material.albedo, material.sssAmount, distanceTraveled, LoV);

		radiance += directIrradiance * ((diffuse + specular) * visibility + subsurface) * getCloudShadows(colortex7, scenePos);
	}

	// Blocklight

	vec3 bsdf = material.albedo * rcpPi;

	vec3 blocklightColor = BLOCKLIGHT_INTENSITY * blackbody(BLOCKLIGHT_TEMPERATURE);
	float blocklightFalloff = getBlocklightFalloff(lmCoord.x, ao);

	radiance += bsdf * blocklightColor * blocklightFalloff;

	// Skylight

	float skylightFalloff = getSkylightFalloff(lmCoord.y);

	radiance += bsdf * skylight * skylightFalloff * ao;

	// Self-emission

	radiance += material.emission;

	return radiance;
}

#endif // INCLUDE_LIGHTING_LIGHTING
