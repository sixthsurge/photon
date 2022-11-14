#if !defined BSDF_INCLUDED
#define BSDF_INCLUDED

#include "/include/utility/fastMath.glsl"

float f0ToIor(float f0) {
	float sqrtF0 = sqrt(f0) * 0.99999;
	return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}

// https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
float distributionGgx(float NoHSq, float alphaSq) {
	return alphaSq / (pi * sqr(1.0 - NoHSq + NoHSq * alphaSq));
}

float v1SmithGgx(float cosTheta, float alphaSq) {
	return 1.0 / (cosTheta + sqrt((-cosTheta * alphaSq + cosTheta) * cosTheta + alphaSq));
}

float v2SmithGgx(float NoL, float NoV, float alphaSq) {
    float ggxL = NoV * sqrt((-NoL * alphaSq + NoL) * NoL + alphaSq);
    float ggxV = NoL * sqrt((-NoV * alphaSq + NoV) * NoV + alphaSq);
    return 0.5 / (ggxL + ggxV);
}

vec3 fresnelSchlick(float cosTheta, vec3 f0) {
	float f = pow5(1.0 - cosTheta);
	return f + f0 * (1.0 - f);
}

vec3 fresnelDielectric(float cosTheta, float f0) {
	float n = f0ToIor(f0);
	float gSq = sqr(n) + sqr(cosTheta) - 1.0;

	if (gSq < 0.0) return vec3(1.0); // Imaginary g => TIR

	float g = sqrt(gSq);
	float a = g - cosTheta;
	float b = g + cosTheta;

	return vec3(0.5 * sqr(a / b) * (1.0 + sqr((b * cosTheta - 1.0) / (a * cosTheta + 1.0))));
}

vec3 fresnelLazanyi2019(float cosTheta, vec3 f0, vec3 f82) {
	vec3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
	float m = pow5(1.0 - cosTheta);
	return clamp01(f0 + (1.0 - f0) * m - a * cosTheta * (m - m * cosTheta));
}

// Modified by Jessie to correctly account for fresnel
vec3 diffuseHammon(
	vec3 albedo,
	float roughness,
	float f0,
	float NoL,
	float NoV,
	float NoH,
	float LoV
) {
	if (NoL <= 0.0) return vec3(0.0);

	float facing = 0.5 * LoV + 0.5;

	float fresnelNL = fresnelDielectric(max(NoL, 1e-2), f0).x;
	float fresnelNV = fresnelDielectric(max(NoV, 1e-2), f0).x;
	float energyConservationFactor = 1.0 - (4.0 * sqrt(f0) + 5.0 * f0 * f0) * (1.0 / 9.0);

	float singleRough = max0(facing) * (-0.2 * facing + 0.45) * (1.0 / NoH + 2.0);
	float singleSmooth = (1.0 - fresnelNL) * (1.0 - fresnelNV) / energyConservationFactor;

	float single = mix(singleSmooth, singleRough, roughness) * rcpPi;
	float multi = 0.1159 * roughness;

	return albedo * multi + single;
}

#endif // BSDF_INCLUDED
