#if !defined INCLUDE_LIGHTING_BSDF
#define INCLUDE_LIGHTING_BSDF

#include "/include/utility/fast_math.glsl"

float f0_to_ior(float f0) {
	float sqrt_f0 = sqrt(f0) * 0.99999;
	return (1.0 + sqrt_f0) / (1.0 - sqrt_f0);
}

// https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
float distribution_ggx(float NoH_sq, float alpha_sq) {
	return alpha_sq / (pi * sqr(1.0 - NoH_sq + NoH_sq * alpha_sq));
}

float v1_smith_ggx(float cos_theta, float alpha_sq) {
	return 1.0 / (cos_theta + sqrt((-cos_theta * alpha_sq + cos_theta) * cos_theta + alpha_sq));
}

float v2_smith_ggx(float NoL, float NoV, float alpha_sq) {
    float ggx_l = NoV * sqrt((-NoL * alpha_sq + NoL) * NoL + alpha_sq);
    float ggx_v = NoL * sqrt((-NoV * alpha_sq + NoV) * NoV + alpha_sq);
    return 0.5 / (ggx_l + ggx_v);
}

vec3 fresnel_schlick(float cos_theta, vec3 f0) {
	float f = pow5(1.0 - cos_theta);
	return f + f0 * (1.0 - f);
}

vec3 fresnel_dielectric_n(float cos_theta, float n) {
	float g_sq = sqr(n) + sqr(cos_theta) - 1.0;

	if (g_sq < 0.0) return vec3(1.0); // Imaginary g => TIR

	float g = sqrt(g_sq);
	float a = g - cos_theta;
	float b = g + cos_theta;

	return vec3(0.5 * sqr(a / b) * (1.0 + sqr((b * cos_theta - 1.0) / (a * cos_theta + 1.0))));
}

vec3 fresnel_dielectric(float cos_theta, float f0) {
	float n = f0_to_ior(f0);
	return fresnel_dielectric_n(cos_theta, n);
}

vec3 fresnel_lazanyi_2019(float cos_theta, vec3 f0, vec3 f82) {
	vec3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
	float m = pow5(1.0 - cos_theta);
	return clamp01(f0 + (1.0 - f0) * m - a * cos_theta * (m - m * cos_theta));
}

// Modified by Jessie to correctly account for fresnel
vec3 diffuse_hammon(
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

	float fresnel_nl = fresnel_dielectric(max(NoL, 1e-2), f0).x;
	float fresnel_nv = fresnel_dielectric(max(NoV, 1e-2), f0).x;
	float energy_conservation_factor = 1.0 - (4.0 * sqrt(f0) + 5.0 * f0 * f0) * (1.0 / 9.0);

	float single_rough = max0(facing) * (-0.2 * facing + 0.45) * (1.0 / NoH + 2.0);
	float single_smooth = (1.0 - fresnel_nl) * (1.0 - fresnel_nv) / energy_conservation_factor;

	float single = mix(single_smooth, single_rough, roughness) * rcp_pi;
	float multi = 0.1159 * roughness;

	return albedo * multi + single;
}

#endif // INCLUDE_LIGHTING_BSDF
