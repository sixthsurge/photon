#if !defined SPECULARLIGHTING_INCLUDED
#define SPECULARLIGHTING_INCLUDED

// GGX spherical area light approximation from Horizon: Zero Dawn
// Source: https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
float getNoHSquared(
	float NoL,
	float NoV,
	float LoV,
	float lightRadius
) {
	float radiusCos = cos(lightRadius);
	float radiusTan = tan(lightRadius);

	// Early out if R falls within the disc​
	float RoL = 2.0 * NoL * NoV - LoV;
	if (RoL >= radiusCos) return 1.0;

	float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RoL * RoL);
	float NoTr = rOverLengthT * (NoV - RoL * NoL);
	float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * LoV);

	// Calculate dot(cross(N, L), V). This could already be calculated and available.​
	float triple = sqrt(clamp01(1.0 - NoL * NoL - NoV * NoV - LoV * LoV + 2.0 * NoL * NoV * LoV));

	// Do one Newton iteration to improve the bent light Direction​
	float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
	float NoLVTr = NoL * radiusCos + NoV + NoTr, LoVVTr = LoV * radiusCos + 1.0 + VoTr;
	float p = NoBr * LoVVTr, q = NoLVTr * LoVVTr, s = VoBr * NoLVTr;
	float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
	float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * LoVVTr * LoVVTr
		+ q * (-0.5 * (LoVVTr + LoV * radiusCos) - 0.5));
	float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
	float sinTheta = twoX1 * xDenom;
	float cosTheta = 1.0 - twoX1 * xNum;
	NoTr = cosTheta * NoTr + sinTheta * NoBr; // use new T to update NoTr​
	VoTr = cosTheta * VoTr + sinTheta * VoBr; // use new T to update VoTr​

	// Calculate (N.H)^2 based on the bent light direction​
	float newNoL = NoL * radiusCos + NoTr;
	float newLoV = LoV * radiusCos + VoTr;
	float NoH = NoV + newNoL;
	float HoH = 2.0 * newLoV + 2.0;

	return clamp01(NoH * NoH / HoH);
}

vec3 getSpecularHighlight(
	Material material,
	float NoL,
	float NoV,
	float NoH,
	float LoV,
	float LoH
) {
	const float specularMaxValue = 4.0; // Maximum value imposed on specular highlight to prevent it from overloading bloom

#if   defined WORLD_OVERWORLD
	float lightRadius = (sunAngle < 0.5) ? (0.57 * degree) : (1.0 * degree);
#endif

	vec3 fresnel;
	if (material.isHardcodedMetal) {
		fresnel = fresnelLazanyi2019(LoH, material.f0, material.f82);
	} else if (material.isMetal) {
		fresnel = fresnelSchlick(LoH, material.albedo);
	} else {
		fresnel = fresnelDielectric(LoH, material.refractiveIndex);
	}

	if (NoL <= eps) return vec3(0.0);
	if (all(lessThan(fresnel, vec3(1e-2)))) return vec3(0.0);

	vec3 albedoTint = mix(vec3(1.0), material.albedo, float(material.isHardcodedMetal));

	float NoHSq = getNoHSquared(NoL, NoV, LoV, lightRadius);
	float alphaSq = material.roughness * material.roughness;

	float d = distributionGgx(NoHSq, alphaSq);
	float v = v2SmithGgx(max(NoL, 1e-2), max(NoV, 1e-2), alphaSq);

	return min((NoL * d * v) * fresnel * albedoTint, vec3(specularMaxValue));
}
#endif // SPECULARLIGHTING_INCLUDED
