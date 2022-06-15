#if !defined INCLUDE_LIGHTING_BSDF
#define INCLUDE_LIGHTING_BSDF

#include "/include/utility/fastMath.glsl"

// GGX spherical area light approximation from Horizon: Zero Dawn
// https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
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

	return max(0.0, NoH * NoH / HoH);
}

float distributionGgx(float NoHSq, float alphaSq) {
	return alphaSq / (pi * sqr(1.0 - NoHSq + NoHSq * alphaSq));
}

float v1SmithGgx(float cosTheta, float alphaSq) {
	return 1.0 / (cosTheta + sqrt((-cosTheta * alphaSq + cosTheta) * cosTheta + alphaSq));
}

float visibilitySmithGgxCorrelated(float NoL, float NoV, float alphaSq) {
    float ggxL = NoV * sqrt((-NoL * alphaSq + NoL) * NoL + alphaSq);
    float ggxV = NoL * sqrt((-NoV * alphaSq + NoV) * NoV + alphaSq);
    return 0.5 / (ggxL + ggxV);
}

vec3 fresnelSchlick(float cosTheta, vec3 f0) {
	float f = pow5(1.0 - cosTheta);
	return f + f0 * (1.0 - f);
}

float fresnelDielectric(float cosTheta, float n) {
	float gSq = sqr(n) + sqr(cosTheta) - 1.0;

	if (gSq < 0.0) return 1.0; // Imaginary g => TIR

	float g = sqrt(gSq);
	float a = g - cosTheta;
	float b = g + cosTheta;

	return 0.5 * sqr(a / b) * (1.0 + sqr((b * cosTheta - 1.0) / (a * cosTheta + 1.0)));
}

// https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
// Modified by Jessie to correctly account for fresnel
vec3 diffuseBrdf(
	vec3 albedo,
	float f0,
	float n,
	float roughness,
	float NoL,
	float NoV,
	float NoH,
	float LoV
) {
	if (NoL <= 0.0) return vec3(0.0);

	float facing = 0.5 * LoV + 0.5;

	float fresnelNL = fresnelDielectric(max(NoL, 1e-2), n);
	float fresnelNV = fresnelDielectric(max(NoV, 1e-2), n);
	float energyConservationFactor = 1.0 - (4.0 * sqrt(f0) + 5.0 * f0 * f0) * (1.0 / 9.0);

	float singleRough = facing * (-0.2 * facing + 0.45) * (1.0 / NoH + 2.0);
	float singleSmooth = (1.0 - fresnelNL) * (1.0 - fresnelNV) / energyConservationFactor;

	float single = mix(singleSmooth, singleRough, roughness) * rcpPi;
	float multi = 0.1159 * roughness;

	return albedo * (albedo * multi + single);
}

vec3 specularBrdf(
	Material material,
	float NoL,
	float NoV,
	float NoH,
	float LoV,
	float LoH,
	float lightRadius
) {
	vec3 f = material.isMetal ? vec3(fresnelDielectric(LoH, material.n)) : fresnelSchlick(LoH, material.f0);

	if (all(lessThan(f, vec3(1e-2)))) return vec3(0.0);

	vec3 albedoTint = material.isHardcodedMetal ? material.albedo : vec3(1.0);

	float NoHSq = getNoHSquared(NoL, NoV, LoV, lightRadius);
	float alphaSq = material.roughness * material.roughness;

	float d = distributionGgx(min(NoHSq, 1.0), alphaSq);
	float v = visibilitySmithGgxCorrelated(max(NoL, 1e-2), max(NoV, 1e-2), alphaSq);

	return (d * v) * f * albedoTint;
}

#endif // INCLUDE_LIGHTING_BSDF
