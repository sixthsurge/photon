#if !defined INCLUDE_FRAGMENT_ACES_TONESCALES
#define INCLUDE_FRAGMENT_ACES_TONESCALES

#include "utility.glsl"

struct SegmentedSplineParamsC5 {
	float slopeLow;     // log-log slope of low linear extension
	float slopeHigh;    // log-log slope of high linear extension
	vec2 logMinPoint; // {log luminance, log luminance} linear extension below this
	vec2 logMidPoint; // {log luminance, log luminance}
	vec2 logMaxPoint; // {log luminance, log luminance} linear extension above this
	float[6] coeffLow;  // Coefficients for B-spline between mid point and max point (units of log luminance)
	float[6] coeffHigh; // Coefficients for B-spline between min point and mid point (units of log luminance)
};

struct SegmentedSplineParamsC9 {
	float slopeLow;      // log-log slope of low linear extension
	float slopeHigh;     // log-log slope of high linear extension
	vec2 logMinPoint;  // {log luminance, log luminance} linear extension below this
	vec2 logMidPoint;  // {log luminance, log luminance}
	vec2 logMaxPoint;  // {log luminance, log luminance} linear extension above this
	float[10] coeffLow;  // Coefficients for B-spline between mid point and max point (units of log luminance)
	float[10] coeffHigh; // Coefficients for B-spline between min point and mid point (units of log luminance)
};

// Textbook monomial to basis-function conversion matrix
const mat3 M = mat3(
	 0.5, -1.0,  0.5,
	-1.0,  1.0,  0.5,
	 0.5,  0.0,  0.0
);

float segmentedSplineC5Fwd(float x) {
	// RRT parameters
	const SegmentedSplineParamsC5 params = SegmentedSplineParamsC5(
		0.0, // slopeLow
		0.0, // slopeHigh
		log(vec2(0.18 * exp2(-15.0), 0.0001)) * rcp(log(10.0)), // logMinPoint
		log(vec2(0.18              ,    4.8)) * rcp(log(10.0)), // logMidPoint
		log(vec2(0.18 * exp2( 18.0), 1000.0)) * rcp(log(10.0)), // logMaxPoint
		// coeffLow
		float[6](-4.0000000000, -4.0000000000, -3.1573765773, -0.4852499958,  1.8477324706,  1.8477324706),
		// coeffHigh
		float[6](-0.7185482425,  2.0810307172,  3.6681241237,  4.0000000000,  4.0000000000,  4.0000000000)
	);

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to 1e-6
	float logX = log10(max(x, eps));
	float logY;

	if (logX <= params.logMinPoint.x) {
		logY = logX * params.slopeLow + (params.logMinPoint.y - params.slopeLow * params.logMinPoint.x);
	} else if ((logX > params.logMinPoint.x) && (logX < params.logMidPoint.x)) {
		float knotCoord = 3.0 * (logX - params.logMinPoint.x) / (params.logMidPoint.x - params.logMinPoint.x);
		uint i = uint(knotCoord);
		float f = fract(knotCoord);

		vec3 cf = vec3(
			params.coeffLow[i    ],
			params.coeffLow[i + 1],
			params.coeffLow[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		logY = dot(monomials, M * cf);
	} else if ((logX >= params.logMidPoint.x) && (logX <= params.logMaxPoint.x)) {
		float knotCoord = 3.0 * (logX - params.logMidPoint.x) / (params.logMaxPoint.x - params.logMidPoint.x);
		uint i = uint(knotCoord);
		float f = fract(knotCoord);

		vec3 cf = vec3(
			params.coeffHigh[i    ],
			params.coeffHigh[i + 1],
			params.coeffHigh[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		logY = dot(monomials, M * cf);
	} else {
		logY = logX * params.slopeHigh + (params.logMaxPoint.y - params.slopeHigh * params.logMaxPoint.x);
	}

	return pow(10.0, logY);
}

float segmentedSplineC9Fwd(float x) {
	// 48nit ODT parameters
	const SegmentedSplineParamsC9 params = SegmentedSplineParamsC9(
		0.0,  // slopeLow
		0.04, // slopeHigh
		// ODT min/max/mid points precomputed using a small C++ program
		// This avoids 3 unnecessary SegmentedSplineC5 calls per fragment
		vec2(-2.5406231880, -1.6989699602),
		vec2( 0.6812411547,  0.6812412143),
		vec2( 3.0024764538,  1.6812412739),
		// coeffLow
		float[10](-1.6989700043, -1.6989700043, -1.4779000000, -1.2291000000, -0.8648000000, -0.4480000000,  0.0051800000,  0.4511080334,  0.9113744414,  0.9113744414),
		// coeffHigh
		float[10]( 0.5154386965,  0.8470437783,  1.1358000000,  1.3802000000,  1.5197000000,  1.5985000000,  1.6467000000,  1.6746091357,  1.6878733390,  1.6878733390)
	);

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to 1e-6
	float logX = log10(max(x, eps));
	float logY;

	if (logX <= params.logMinPoint.x) {
		logY = logX * params.slopeLow + (params.logMinPoint.y - params.slopeLow * params.logMinPoint.x);
	} else if ((logX > params.logMinPoint.x) && (logX < params.logMidPoint.x)) {
		float knotCoord = 7.0 * (logX - params.logMinPoint.x) / (params.logMidPoint.x - params.logMinPoint.x);
		uint i = uint(knotCoord);
		float f = fract(knotCoord);

		vec3 cf = vec3(
			params.coeffLow[i    ],
			params.coeffLow[i + 1],
			params.coeffLow[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		logY = dot(monomials, M * cf);
	} else if ((logX >= params.logMidPoint.x) && (logX <= params.logMaxPoint.x)) {
		float knotCoord = 7.0 * (logX - params.logMidPoint.x) / (params.logMaxPoint.x - params.logMidPoint.x);
		uint i = uint(knotCoord);
		float f = fract(knotCoord);

		vec3 cf = vec3(
			params.coeffHigh[i    ],
			params.coeffHigh[i + 1],
			params.coeffHigh[i + 2]
		);

		vec3 monomials = vec3(f * f, f, 1.0);

		logY = dot(monomials, M * cf);
	} else {
		logY = logX * params.slopeHigh + (params.logMaxPoint.y - params.slopeHigh * params.logMaxPoint.x);
	}

	return pow(10.0, logY);
}

#endif // INCLUDE_FRAGMENT_ACES_TONESCALES
