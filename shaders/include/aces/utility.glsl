#if !defined ACES_UTILITY_INCLUDED
#define ACES_UTILITY_INCLUDED

#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"

mat3 getChromaticAdaptationMatrix(vec3 srcXyz, vec3 dstXyz) {
	const mat3 bradfordConeResponse = mat3(
		0.89510, -0.75020,  0.03890,
		0.26640,  1.71350, -0.06850,
		-0.16140,  0.03670,  1.02960
	);

	vec3 srcLms = srcXyz * bradfordConeResponse;
	vec3 dstLms = dstXyz * bradfordConeResponse;
	vec3 quotient = dstLms / srcLms;

	mat3 vonKries = mat3(
		quotient.x, 0.0, 0.0,
		0.0, quotient.y, 0.0,
		0.0, 0.0, quotient.z
	);

	return (bradfordConeResponse * vonKries) * inverse(bradfordConeResponse); // please invert at compile time
}

float log10(float x) {
	return log(x) * rcp(log(10.0));
}

vec3 yToLinCV(vec3 y, float yMax, float yMin) {
	return (y - yMin) / (yMax - yMin);
}

// Transformations between CIE XYZ tristimulus values and CIE x,y chromaticity
// coordinates
vec3 XYZ_to_xyY(vec3 XYZ) {
	float mul = 1.0 / max(XYZ.x + XYZ.y + XYZ.z, 1e-10);

	return vec3(
		XYZ.x * mul,
		XYZ.y * mul,
		XYZ.y
	);
}
vec3 xyY_to_XYZ(vec3 xyY) {
	float mul = xyY.z / max(xyY.y, 1e-10);

	return vec3(
		xyY.x * mul,
		xyY.z,
		(1.0 - xyY.x - xyY.y) * mul
	);
}

// Transformations from RGB to other color representations

float rgbToSaturation(vec3 rgb) {
	float maxComponent = max(maxOf(rgb), 1e-10);
	float minComponent = max(minOf(rgb), 1e-10);

	return (maxComponent - minComponent) / maxComponent;
}

// Returns a geometric hue angle in degrees (0-360) based on RGB values
// For neutral colors, hue is undefined and the function will return zero (The reference
// implementation returns NaN but I think that's silly)
float rgbToHue(vec3 rgb) {
	if (rgb.r == rgb.g && rgb.g == rgb.b) return float(0.0);

	float hue = (360.0 / tau) * atan(2.0 * rgb.r - rgb.g - rgb.b, sqrt(3.0) * (rgb.g - rgb.b));

	if (hue < 0.0) hue += 360.0;

	return hue;
}

// Converts RGB to a luminance proxy, here called YC
// YC is ~ Y + K * Chroma
float rgbToYc(vec3 rgb) {
	const float ycRadiusWeight = 1.75;

	float chroma = sqrt(rgb.b * (rgb.b - rgb.g) + rgb.g * (rgb.g - rgb.r) + rgb.r * (rgb.r - rgb.b));

	return rcp(3.0) * (rgb.r + rgb.g + rgb.b + ycRadiusWeight * chroma);
}

#endif // ACES_UTILITY_INCLUDED
