#if !defined INCLUDE_UTILITY_FASTMATH
#define INCLUDE_UTILITY_FASTMATH

// Faster alternative to acos
// Source: https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/#more-3316
// Max relative error: 3.9 * 10^-4
// Max absolute error: 6.1 * 10^-4
// Polynomial degree: 2
float acosApprox(float x) {
	const float C0 = 1.57018;
	const float C1 = -0.201877;
	const float C2 = 0.0464619;

	float res = (C2 * abs(x) + C1) * abs(x) + C0; // p(x)
	res *= sqrt(1.0 - abs(x));

	return x >= 0 ? res : pi - res; // Undo range reduction
}

float pow4(float x) { return sqr(sqr(x)); }
float pow5(float x) { return pow4(x) * x; }
float pow6(float x) { return sqr(cube(x)); }
float pow7(float x) { return pow6(x) * x; }
float pow8(float x) { return sqr(pow4(x)); }

float pow16(float x) {
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	return x;
}

float cube2(float x) {
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	return x;
}

float pow64(float x) {
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	return x;
}

float pow128(float x) {
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	x *= x;
	return x;
}

float pow1d5(float x) {
	return x * sqrt(x);
}

float rcpLength(vec2 v) { return inversesqrt(dot(v, v)); }
float rcpLength(vec3 v) { return inversesqrt(dot(v, v)); }

#endif // INCLUDE_UTILITY_FASTMATH
