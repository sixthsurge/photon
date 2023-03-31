#if !defined INCLUDE_ACES_UTILITY
#define INCLUDE_ACES_UTILITY

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"

mat3 get_chromatic_adaptation_matrix(vec3 src_xyz, vec3 dst_xyz) {
	const mat3 bradford_cone_response = mat3(
		0.89510, -0.75020,  0.03890,
		0.26640,  1.71350, -0.06850,
		-0.16140,  0.03670,  1.02960
	);

	vec3 src_lms = src_xyz * bradford_cone_response;
	vec3 dst_lms = dst_xyz * bradford_cone_response;
	vec3 quotient = dst_lms / src_lms;

	mat3 von_kries = mat3(
		quotient.x, 0.0, 0.0,
		0.0, quotient.y, 0.0,
		0.0, 0.0, quotient.z
	);

	return (bradford_cone_response * von_kries) * inverse(bradford_cone_response); // please invert at compile time
}

float log10(float x) {
	return log(x) * rcp(log(10.0));
}

vec3 y_to_lin_c_v(vec3 y, float y_max, float y_min) {
	return (y - y_min) / (y_max - y_min);
}

// Transformations between CIE XYZ tristimulus values and CIE x,y chromaticity
// coordinates
vec3 XYZ_to_xy_y(vec3 XYZ) {
	float mul = 1.0 / max(XYZ.x + XYZ.y + XYZ.z, 1e-10);

	return vec3(
		XYZ.x * mul,
		XYZ.y * mul,
		XYZ.y
	);
}
vec3 xy_y_to_XYZ(vec3 xy_y) {
	float mul = xy_y.z / max(xy_y.y, 1e-10);

	return vec3(
		xy_y.x * mul,
		xy_y.z,
		(1.0 - xy_y.x - xy_y.y) * mul
	);
}

// Transformations from RGB to other color representations

float rgb_to_saturation(vec3 rgb) {
	float max_component = max(max_of(rgb), 1e-10);
	float min_component = max(min_of(rgb), 1e-10);

	return (max_component - min_component) / max_component;
}

// Returns a geometric hue angle in degrees (0-360) based on RGB values
// For neutral colors, hue is undefined and the function will return zero (The reference
// implementation returns NaN but I think that's silly)
float rgb_to_hue(vec3 rgb) {
	if (rgb.r == rgb.g && rgb.g == rgb.b) return float(0.0);

	float hue = (360.0 / tau) * atan(2.0 * rgb.r - rgb.g - rgb.b, sqrt(3.0) * (rgb.g - rgb.b));

	if (hue < 0.0) hue += 360.0;

	return hue;
}

// Converts RGB to a luminance proxy, here called YC
// YC is ~ Y + K * Chroma
float rgb_to_yc(vec3 rgb) {
	const float yc_radius_weight = 1.75;

	float chroma = sqrt(rgb.b * (rgb.b - rgb.g) + rgb.g * (rgb.g - rgb.r) + rgb.r * (rgb.r - rgb.b));

	return rcp(3.0) * (rgb.r + rgb.g + rgb.b + yc_radius_weight * chroma);
}

#endif // INCLUDE_ACES_UTILITY
