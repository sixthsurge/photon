#if !defined INCLUDE_ACES_ACES
#define INCLUDE_ACES_ACES

/*
 * Implemented following the reference implementation given by the Academy at
 * https://github.com/ampas/aces-dev (revision 1.3)
 */

#include "matrices.glsl"
#include "tonescales.glsl"
#include "utility.glsl"

// Constants

const float rrt_glow_gain   = 0.1;   // default: 0.05
const float rrt_glow_mid    = 0.08;  // default: 0.08

const float rrt_red_scale   = 1.0;   // default: 0.82
const float rrt_red_pivot   = 0.03;  // default: 0.03
const float rrt_red_hue     = 0.0;   // default: 0.0
const float rrt_red_width   = 135.0; // default: 135.0

const float rrt_sat_factor  = 0.96;  // default: 0.96
const float odt_sat_factor  = 1.0;   // default: 0.93

const float rrt_gamma_curve = 0.96;

const float cinema_white    = 48.0;  // default: 48.0
const float cinema_black    = 0.02;  // default: 10^log_10(0.02)

// "Glow module" functions

float glow_fwd(float yc_in, float glow_gain_in, const float glow_mid) {
	float glow_gain_out;

	if (yc_in <= 2.0 / 3.0 * glow_mid)
		glow_gain_out = glow_gain_in;
	else if (yc_in >= 2.0 * glow_mid)
		glow_gain_out = 0.0;
	else
		glow_gain_out = glow_gain_in * (glow_mid / yc_in - 0.5);

	return glow_gain_out;
}

// Sigmoid function in the range 0 to 1 spanning -2 to +2
float sigmoid_shaper(float x) {
	float t = max0(1.0 - abs(0.5 * x));
	float y = 1.0 + sign(x) * (1.0 - t * t);

	return float(0.5) * y;
}

// "Red modifier" functions

float cubic_basis_shaper(float x, const float width) {
	const mat4 M = mat4(
		vec4(-1.0,  3.0, -3.0,  1.0) / 6.0,
		vec4( 3.0, -6.0,  3.0,  0.0) / 6.0,
		vec4(-3.0,  0.0,  3.0,  0.0) / 6.0,
		vec4( 1.0,  4.0,  1.0,  0.0) / 6.0
	);

	float knots[5] = float[](
		-0.5  * width,
		-0.25 * width,
		 0.0,
		 0.25 * width,
		 0.5  * width
	);

	float knot_coord = (x - knots[0]) * 4.0 / width;
	uint i = 3 - uint(clamp(knot_coord, 0.0, 3.0));
	float f = fract(knot_coord);

	if (x < knots[0] || x > knots[4] || i > 3) return 0.0;

	vec4 monomials = vec4(f * f * f, f * f, f, 1.0);

	float y = monomials[0] * M[0][i] + monomials[1] * M[1][i]
	        + monomials[2] * M[2][i] + monomials[3] * M[3][i];

	return 1.5 * y;
}

float cubic_basis_shaper_fit(float x, const float width) {
	float radius = 0.5 * width;
	return abs(x) < radius
		? sqr(cubic_smooth(1.0 - abs(x) / radius))
		: 0.0;
}

float center_hue(float hue, float center_h) {
	float hue_centered = hue - center_h;

	if (hue_centered < -180.0) {
		return hue_centered + 360.0;
	} else if (hue_centered > 180.0) {
		return hue_centered - 360.0;
	} else {
		return hue_centered;
	}
}

vec3 rrt_sweeteners(vec3 aces) {
	// Glow module
	float saturation = rgb_to_saturation(aces);
	float yc_in = rgb_to_yc(aces);
	float s = sigmoid_shaper(5.0 * saturation - 2.0);
	float added_glow = 1.0 + glow_fwd(yc_in, rrt_glow_gain * s, rrt_glow_mid);

	aces *= added_glow;

	// Red modifier
	float hue = rgb_to_hue(aces);
	float centered_hue = center_hue(hue, rrt_red_hue);
	float hue_weight = cubic_basis_shaper_fit(centered_hue, rrt_red_width);

	aces.r = aces.r + hue_weight * saturation * (rrt_red_pivot - aces.r) * (1.0 - rrt_red_scale);

	// ACES to RGB rendering space
	vec3 rgb_pre = max0(aces) * ap0_to_ap1;

	// Global desaturation
	float luminance = dot(rgb_pre, luminance_weights_ap1);
	rgb_pre = mix(vec3(luminance), rgb_pre, rrt_sat_factor);

	// Added gamma adjustment before the RRT
	rgb_pre = pow(rgb_pre, vec3(rrt_gamma_curve));

	return rgb_pre;
}

/*
 * Reference Rendering Transform (RRT)
 *
 * Modifications:
 * Changed input and output color space to ACEScg to avoid 2 unnecessary mat3 transformations
 */
vec3 aces_rrt(vec3 aces) {
	// Apply RRT sweeteners
	vec3 rgb_pre = rrt_sweeteners(aces);

	// Apply the tonescale independently in rendering-space RGB
	vec3 rgb_post;
	rgb_post.r = segmented_spline_c5_fwd(rgb_pre.r);
	rgb_post.g = segmented_spline_c5_fwd(rgb_pre.g);
	rgb_post.b = segmented_spline_c5_fwd(rgb_pre.b);

	return rgb_post;
}

// Gamma adjustment to compensate for dim surround
vec3 dark_surround_to_dim_surround(vec3 linear_c_v) {
	const float dim_surround_gamma = 0.9811; // default: 0.9811

	vec3 XYZ = linear_c_v * ap1_to_xyz;
	vec3 xy_y = XYZ_to_xy_y(XYZ);

	xy_y.z = max0(xy_y.z);
	xy_y.z = pow(xy_y.z, dim_surround_gamma);

	return xy_y_to_XYZ(xy_y) * xyz_to_ap1;
}

/*
 * Output Device Transform - Rec709
 *
 * Summary:
 * This transform is intended for mapping OCES onto a Rec.709 broadcast monitor
 * that is calibrated to a D65 white point at 100 cd/m^2. The assumed observer
 * adapted white is D65, and the viewing environment is a dim surround.
 *
 * Modifications:
 * Changed input and output color spaces to ACEScg to avoid 3 unnecessary mat3 transformations
 * The s_r_g_b transfer function is applied later in the pipeline
 */
vec3 aces_odt(vec3 rgb_pre) {
	// Apply the tonescale independently in rendering-space RGB
	vec3 rgb_post;
	rgb_post.r = segmented_spline_c9_fwd(rgb_pre.r);
	rgb_post.g = segmented_spline_c9_fwd(rgb_pre.g);
	rgb_post.b = segmented_spline_c9_fwd(rgb_pre.b);

	// Scale luminance to linear code value
	vec3 linear_c_v = y_to_lin_c_v(rgb_post, cinema_white, cinema_black);

	// Apply gamma adjustment to compensate for dim surround
	linear_c_v = dark_surround_to_dim_surround(linear_c_v);

	// Apply desaturation to compensate for luminance difference
	float luminance = dot(linear_c_v, luminance_weights_ap1);
	linear_c_v = mix(vec3(luminance), linear_c_v, odt_sat_factor);

	return linear_c_v;
}

/*
 * RRT + ODT fit by Stephen Hill
 * https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
 */
vec3 rrt_and_odt_fit(vec3 rgb) {
	vec3 a = rgb * (rgb + 0.0245786) - 0.000090537;
	vec3 b = rgb * (0.983729 * rgb + 0.4329510) + 0.238081;

	return a / b;
}

#endif // INCLUDE_ACES_ACES
