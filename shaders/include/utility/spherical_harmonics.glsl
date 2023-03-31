#if !defined INCLUDE_UTILITY_SPHERICAL_HARMONICS
#define INCLUDE_UTILITY_SPHERICAL_HARMONICS

float[4] sh_coeff_order_1(vec3 direction) {
	float x = direction.x;
	float y = direction.y;
	float z = direction.z;

	return float[4](
		0.2820947918,
		0.4886025119 * x,
		0.4886025119 * z,
		0.4886025119 * y
	);
}

float[9] sh_coeff_order_2(vec3 direction) {
	float x = direction.x;
	float y = direction.y;
	float z = direction.z;

	return float[9](
		0.2820947918,
		0.4886025119 * x,
		0.4886025119 * z,
		0.4886025119 * y,
		1.0925484310 * x * y,
		1.0925484310 * y * z,
		0.3153915653 * (3.0 * z * z - 1.0),
		0.7725484040 * x * z,
		0.3862742020 * (x * x - y * y)
	);
}

vec3 sh_evaluate(vec3[4] f, vec3 direction) {
	float coeff[4] = sh_coeff_order_1(direction);

	return coeff[0] * f[0]
	     + coeff[1] * f[1]
	     + coeff[2] * f[2]
	     + coeff[3] * f[3];
}

vec3 sh_evaluate(vec3[9] f, vec3 direction) {
	float coeff[9] = sh_coeff_order_2(direction);

	return coeff[0] * f[0]
	     + coeff[1] * f[1]
	     + coeff[2] * f[2]
	     + coeff[3] * f[3]
	     + coeff[4] * f[4]
	     + coeff[5] * f[5]
	     + coeff[6] * f[6]
	     + coeff[7] * f[7]
	     + coeff[8] * f[8];
}

// Convolve SH using circularly symmetric kernel
vec3[9] sh_convolve(vec3[9] f, vec3 kernel) {
	const vec3 k = sqrt(4.0 * pi / vec3(1.0, 3.0, 5.0));

	vec3 mul = k * kernel;

	return vec3[9](
		f[0] * mul.x,
		f[1] * mul.y,
		f[2] * mul.y,
		f[3] * mul.y,
		f[4] * mul.z,
		f[5] * mul.z,
		f[6] * mul.z,
		f[7] * mul.z,
		f[8] * mul.z
	);
}

vec3 sh_evaluate_convolved(vec3[9] f, vec3 kernel, vec3 direction) {
	const vec3 k = sqrt(4.0 * pi / vec3(1.0, 3.0, 5.0));

	vec3 mul = k * kernel;
	float coeff[9] = sh_coeff_order_2(direction);

	return coeff[0] * f[0] * mul.x
	     + coeff[1] * f[1] * mul.y
	     + coeff[2] * f[2] * mul.y
	     + coeff[3] * f[3] * mul.y
	     + coeff[4] * f[4] * mul.z
	     + coeff[5] * f[5] * mul.z
	     + coeff[6] * f[6] * mul.z
	     + coeff[7] * f[7] * mul.z
	     + coeff[8] * f[8] * mul.z;
}

// https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf section 5
vec3 sh_evaluate_irradiance(vec3[9] sh, vec3 bent_normal, float visibility) {
	float aperture_angle_sin_sq = clamp01(visibility);
	float aperture_angle_cos_sq = 1.0 - aperture_angle_sin_sq;

	// Zonal harmonics expansion of visibility cone
	vec3 kernel;
	kernel.x = (sqrt(1.0 * pi) /  2.0) * aperture_angle_sin_sq;
	kernel.y = (sqrt(3.0 * pi) /  3.0) * (1.0 - aperture_angle_cos_sq * sqrt(aperture_angle_cos_sq));
	kernel.z = (sqrt(5.0 * pi) / 16.0) * aperture_angle_sin_sq * (2.0 + 6.0 * aperture_angle_cos_sq);

	return sh_evaluate_convolved(sh, kernel, bent_normal);
}

#endif // INCLUDE_UTILITY_SPHERICAL_HARMONICS
