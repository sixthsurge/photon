#if !defined INCLUDE_ACES_TONESCALES
#define INCLUDE_ACES_TONESCALES

#include "utility.glsl"

struct SegmentedSplineParamsC5 {
	float slope_low;     // log-log slope of low linear extension
	float slope_high;    // log-log slope of high linear extension
	vec2 log_min_point; // {log luminance, log luminance} linear extension below this
	vec2 log_mid_point; // {log luminance, log luminance}
	vec2 log_max_point; // {log luminance, log luminance} linear extension above this
	float[6] coeff_low;  // Coefficients for B-spline between mid point and max point (units of log luminance)
	float[6] coeff_high; // Coefficients for B-spline between min point and mid point (units of log luminance)
};

struct SegmentedSplineParamsC9 {
	float slope_low;      // log-log slope of low linear extension
	float slope_high;     // log-log slope of high linear extension
	vec2 log_min_point;  // {log luminance, log luminance} linear extension below this
	vec2 log_mid_point;  // {log luminance, log luminance}
	vec2 log_max_point;  // {log luminance, log luminance} linear extension above this
	float[10] coeff_low;  // Coefficients for B-spline between mid point and max point (units of log luminance)
	float[10] coeff_high; // Coefficients for B-spline between min point and mid point (units of log luminance)
};

// Textbook monomial to basis-function conversion matrix
const mat3 M = mat3(
	 0.5, -1.0,  0.5,
	-1.0,  1.0,  0.5,
	 0.5,  0.0,  0.0
);

float segmented_spline_c5_fwd(float x) {
	// RRT parameters
	const SegmentedSplineParamsC5 params = SegmentedSplineParamsC5(
		0.0, // slope_low
		0.0, // slope_high
		log(vec2(0.18 * exp2(-15.0), 0.0001)) * rcp(log(10.0)), // log_min_point
		log(vec2(0.18              ,    4.8)) * rcp(log(10.0)), // log_mid_point
		log(vec2(0.18 * exp2( 18.0), 1000.0)) * rcp(log(10.0)), // log_max_point
		// coeff_low
		float[6](-4.0000000000, -4.0000000000, -3.1573765773, -0.4852499958,  1.8477324706,  1.8477324706),
		// coeff_high
		float[6](-0.7185482425,  2.0810307172,  3.6681241237,  4.0000000000,  4.0000000000,  4.0000000000)
	);

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to 1e-6
	float log_x = log10(max(x, eps));
	float log_y;

	if (log_x <= params.log_min_point.x) {
		log_y = log_x * params.slope_low + (params.log_min_point.y - params.slope_low * params.log_min_point.x);
	} else if (log_x > params.log_min_point.x && log_x < params.log_mid_point.x) {
		float knot_coord = 3.0 * (log_x - params.log_min_point.x) / (params.log_mid_point.x - params.log_min_point.x);
		uint i = uint(knot_coord);
		float f = fract(knot_coord);

		vec3 cf = vec3(
			params.coeff_low[i    ],
			params.coeff_low[i + 1],
			params.coeff_low[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		log_y = dot(monomials, M * cf);
	} else if (log_x >= params.log_mid_point.x && log_x <= params.log_max_point.x) {
		float knot_coord = 3.0 * (log_x - params.log_mid_point.x) / (params.log_max_point.x - params.log_mid_point.x);
		uint i = uint(knot_coord);
		float f = fract(knot_coord);

		vec3 cf = vec3(
			params.coeff_high[i    ],
			params.coeff_high[i + 1],
			params.coeff_high[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		log_y = dot(monomials, M * cf);
	} else {
		log_y = log_x * params.slope_high + (params.log_max_point.y - params.slope_high * params.log_max_point.x);
	}

	return pow(10.0, log_y);
}

float segmented_spline_c9_fwd(float x) {
	// 48nit ODT parameters
	const SegmentedSplineParamsC9 params = SegmentedSplineParamsC9(
		0.0,  // slope_low
		0.04, // slope_high
		// ODT min/max/mid points precomputed using a small C++ program
		// This avoids 3 unnecessary SegmentedSplineC5 calls per fragment
		vec2(-2.5406231880, -1.6989699602),
		vec2( 0.6812411547,  0.6812412143),
		vec2( 3.0024764538,  1.6812412739),
		// coeff_low
		float[10](-1.6989700043, -1.6989700043, -1.4779000000, -1.2291000000, -0.8648000000, -0.4480000000,  0.0051800000,  0.4511080334,  0.9113744414,  0.9113744414),
		// coeff_high
		float[10]( 0.5154386965,  0.8470437783,  1.1358000000,  1.3802000000,  1.5197000000,  1.5985000000,  1.6467000000,  1.6746091357,  1.6878733390,  1.6878733390)
	);

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to 1e-6
	float log_x = log10(max(x, eps));
	float log_y;

	if (log_x <= params.log_min_point.x) {
		log_y = log_x * params.slope_low + (params.log_min_point.y - params.slope_low * params.log_min_point.x);
	} else if ((log_x > params.log_min_point.x) && (log_x < params.log_mid_point.x)) {
		float knot_coord = 7.0 * (log_x - params.log_min_point.x) / (params.log_mid_point.x - params.log_min_point.x);
		uint i = uint(knot_coord);
		float f = fract(knot_coord);

		vec3 cf = vec3(
			params.coeff_low[i    ],
			params.coeff_low[i + 1],
			params.coeff_low[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		log_y = dot(monomials, M * cf);
	} else if ((log_x >= params.log_mid_point.x) && (log_x <= params.log_max_point.x)) {
		float knot_coord = 7.0 * (log_x - params.log_mid_point.x) / (params.log_max_point.x - params.log_mid_point.x);
		uint i = uint(knot_coord);
		float f = fract(knot_coord);

		vec3 cf = vec3(
			params.coeff_high[i    ],
			params.coeff_high[i + 1],
			params.coeff_high[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		log_y = dot(monomials, M * cf);
	} else {
		log_y = log_x * params.slope_high + (params.log_max_point.y - params.slope_high * params.log_max_point.x);
	}

	return pow(10.0, log_y);
}

#endif // INCLUDE_ACES_TONESCALES
