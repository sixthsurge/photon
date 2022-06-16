#if !defined INCLUDE_FRAGMENT_ACES_ACES
#define INCLUDE_FRAGMENT_ACES_ACES

/*
 * Implemented following the reference implementation given by the Academy at
 * https://github.com/ampas/aces-dev (revision 1.3)
 */

#include "matrices.glsl"
#include "tonescales.glsl"
#include "utility.glsl"

//--// Constants

const float rrtGlowGain  = 0.1 * RRT_GLOW_GAIN;   // default: 0.05
const float rrtGlowMid   = 0.08 * RRT_GLOW_MID;   // default: 0.08

const float rrtRedScale  = 1.0 * RRT_RED_SCALE;  // default: 0.82
const float rrtRedPivot  = 0.03;                  // default: 0.03
const float rrtRedHue    = 0.0;                   // default: 0.0
const float rrtRedWidth  = 135.0 * RRT_RED_WIDTH; // default: 135.0

const float rrtSatFactor = 0.95 * RRT_SAT_FACTOR; // default: 0.96
const float odtSatFactor = 1.0 * ODT_SAT_FACTOR; // default: 0.93

const float rrtGammaCurve = 0.96;

const float cinemaWhite  = 48.0; // default: 48.0
const float cinemaBlack  = 0.02; // default: 10^log_10(0.02)

//--// "Glow module" functions

float glowFwd(float ycIn, float glowGainIn, const float glowMid) {
	float glowGainOut;

	if (ycIn <= 2.0 / 3.0 * glowMid) {
		glowGainOut = glowGainIn;
	} else if (ycIn >= 2.0 * glowMid) {
		glowGainOut = 0.0;
	} else {
		glowGainOut = glowGainIn * (glowMid / ycIn - 0.5);
	}

	return glowGainOut;
}

// Sigmoid function in the range 0 to 1 spanning -2 to +2
float sigmoidShaper(float x) {
	float t = max0(1.0 - abs(0.5 * x));
	float y = 1.0 + sign(x) * (1.0 - t * t);

	return float(0.5) * y;
}

//--// "Red modifier" functions

float cubicBasisShaper(float x, const float width) {
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

	float knotCoord = (x - knots[0]) * 4.0 / width;
	uint i = 3 - uint(clamp(knotCoord, 0.0, 3.0));
	float f = fract(knotCoord);

	if (x < knots[0] || x > knots[4] || i > 3) return 0.0;

	vec4 monomials = vec4(f * f * f, f * f, f, 1.0);

	float y = monomials[0] * M[0][i] + monomials[1] * M[1][i]
	        + monomials[2] * M[2][i] + monomials[3] * M[3][i];

	return 1.5 * y;
}

float cubicBasisShaperFit(float x, const float width) {
	float radius = 0.5 * width;
	return abs(x) < radius
		? sqr(cubicSmooth(1.0 - abs(x) / radius))
		: 0.0;
}

float centerHue(float hue, float centerH) {
	float hueCentered = hue - centerH;

	if (hueCentered < -180.0) {
		return hueCentered + 360.0;
	} else if (hueCentered > 180.0) {
		return hueCentered - 360.0;
	} else {
		return hueCentered;
	}
}

vec3 rrtSweeteners(vec3 aces) {
	// Glow module
	float saturation = rgbToSaturation(aces);
	float ycIn = rgbToYc(aces);
	float s = sigmoidShaper(5.0 * saturation - 2.0);
	float addedGlow = 1.0 + glowFwd(ycIn, rrtGlowGain * s, rrtGlowMid);

	aces *= addedGlow;

	// Red modifier
	float hue = rgbToHue(aces);
	float centeredHue = centerHue(hue, rrtRedHue);
	float hueWeight = cubicBasisShaperFit(centeredHue, rrtRedWidth);

	aces.r = aces.r + hueWeight * saturation * (rrtRedPivot - aces.r) * (1.0 - rrtRedScale);

	// ACES to RGB rendering space
	vec3 rgbPre = max0(aces) * ap0ToAp1;

	// Global desaturation
	float luminance = getLuminance(rgbPre);
	rgbPre = mix(vec3(luminance), rgbPre, rrtSatFactor);

	// Added gamma adjustment before the RRT
	rgbPre = pow(rgbPre, vec3(rrtGammaCurve));

	return rgbPre;
}

/*
 * Reference Rendering Transform (RRT)
 *
 * Modifications:
 * Changed input and output color space to ACEScg to avoid 2 unnecessary mat3 transformations
 */
vec3 acesRrt(vec3 aces) {
	// Apply RRT sweeteners
	vec3 rgbPre = rrtSweeteners(aces * ap1ToAp0);

	// Apply the tonescale independently in rendering-space RGB
	vec3 rgbPost;
	rgbPost.r = segmentedSplineC5Fwd(rgbPre.r);
	rgbPost.g = segmentedSplineC5Fwd(rgbPre.g);
	rgbPost.b = segmentedSplineC5Fwd(rgbPre.b);

	return rgbPost;
}

// Gamma adjustment to compensate for dim surround
vec3 darkSurroundToDimSurround(vec3 linearCV) {
	const float dimSurroundGamma = 0.9811; // default: 0.9811

	vec3 XYZ = linearCV * ap1ToXyz;
	vec3 xyY = XYZ_to_xyY(XYZ);

	xyY.z = max0(xyY.z);
	xyY.z = pow(xyY.z, dimSurroundGamma);

	return xyY_to_XYZ(xyY) * xyzToAp1;
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
 * The sRGB transfer function is applied later in the pipeline
 */
vec3 acesOdt(vec3 rgbPre) {
	// Apply the tonescale independently in rendering-space RGB
	vec3 rgbPost;
	rgbPost.r = segmentedSplineC9Fwd(rgbPre.r);
	rgbPost.g = segmentedSplineC9Fwd(rgbPre.g);
	rgbPost.b = segmentedSplineC9Fwd(rgbPre.b);

	// Scale luminance to linear code value
	vec3 linearCV = yToLinCV(rgbPost, cinemaWhite, cinemaBlack);

	// Apply gamma adjustment to compensate for dim surround
	linearCV = darkSurroundToDimSurround(linearCV);

	// Apply desaturation to compensate for luminance difference
	float luminance = getLuminance(linearCV);
	linearCV = mix(vec3(luminance), linearCV, odtSatFactor);

	return linearCV;
}

/*
 * RRT + ODT fit by Stephen Hill
 * https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
 */
vec3 rrtAndOdtFit(vec3 rgb) {
	vec3 a = rgb * (rgb + 0.0245786) - 0.000090537;
	vec3 b = rgb * (0.983729 * rgb + 0.4329510) + 0.238081;

	return a / b;
}

#endif // INCLUDE_FRAGMENT_ACES_ACES
