#if !defined SPECULAR_LIGHTING_INCLUDED
#define SPECULAR_LIGHTING_INCLUDED

// GGX spherical area light approximation from Horizon: Zero Dawn
// Source: https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
float get_NoH_squared(
	float NoL,
	float NoV,
	float LoV,
	float light_radius
) {
	float radius_cos = cos(light_radius);
	float radius_tan = tan(light_radius);

	// Early out if R falls within the disc​
	float RoL = 2.0 * NoL * NoV - LoV;
	if (RoL >= radius_cos) return 1.0;

	float r_over_length_t = radius_cos * radius_tan * inversesqrt(1.0 - RoL * RoL);
	float NoTr = r_over_length_t * (NoV - RoL * NoL);
	float VoTr = r_over_length_t * (2.0 * NoV * NoV - 1.0 - RoL * LoV);

	// Calculate dot(cross(N, L), V). This could already be calculated and available.​
	float triple = sqrt(clamp01(1.0 - NoL * NoL - NoV * NoV - LoV * LoV + 2.0 * NoL * NoV * LoV));

	// Do one Newton iteration to improve the bent light Direction​
	float NoBr = r_over_length_t * triple, VoBr = r_over_length_t * (2.0 * triple * NoV);
	float NoLVTr = NoL * radius_cos + NoV + NoTr, LoVVTr = LoV * radius_cos + 1.0 + VoTr;
	float p = NoBr * LoVVTr, q = NoLVTr * LoVVTr, s = VoBr * NoLVTr;
	float x_num = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
	float x_denom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radius_cos + NoV) * LoVVTr * LoVVTr
		+ q * (-0.5 * (LoVVTr + LoV * radius_cos) - 0.5));
	float two_x_1 = 2.0 * x_num / (x_denom * x_denom + x_num * x_num);
	float sin_theta = two_x_1 * x_denom;
	float cos_theta = 1.0 - two_x_1 * x_num;
	NoTr = cos_theta * NoTr + sin_theta * NoBr; // use new T to update NoTr​
	VoTr = cos_theta * VoTr + sin_theta * VoBr; // use new T to update VoTr​

	// Calculate (N.H)^2 based on the bent light direction​
	float new_NoL = NoL * radius_cos + NoTr;
	float new_LoV = LoV * radius_cos + VoTr;
	float NoH = NoV + new_NoL;
	float HoH = 2.0 * new_LoV + 2.0;

	return clamp01(NoH * NoH / HoH);
}

vec3 get_specular_highlight(
	Material material,
	float NoL,
	float NoV,
	float NoH,
	float LoV,
	float LoH
) {
	const float specular_max_value = 4.0; // Maximum value imposed on specular highlight to prevent it from overloading bloom

#if   defined WORLD_OVERWORLD
	float light_radius = (sunAngle < 0.5) ? (0.57 * degree) : (1.0 * degree);
#endif

	vec3 fresnel;
	if (material.is_hardcoded_metal) {
		fresnel = fresnel_lazanyi_2019(LoH, material.f0, material.f82);
	} else if (material.is_metal) {
		fresnel = fresnel_schlick(LoH, material.albedo);
	} else {
		fresnel = fresnel_dielectric(LoH, material.f0.x);
	}

	if (NoL <= eps) return vec3(0.0);
	if (all(lessThan(fresnel, vec3(1e-2)))) return vec3(0.0);

	vec3 albedo_tint = mix(vec3(1.0), material.albedo, float(material.is_hardcoded_metal));

	float NoHSq = get_NoH_squared(NoL, NoV, LoV, light_radius);
	float alpha_sq = material.roughness * material.roughness;

	float d = distribution_ggx(NoHSq, alpha_sq);
	float v = v2_smith_ggx(max(NoL, 1e-2), max(NoV, 1e-2), alpha_sq);

	return min((NoL * d * v) * fresnel * albedo_tint, vec3(specular_max_value));
}
#endif // SPECULAR_LIGHTING_INCLUDED
