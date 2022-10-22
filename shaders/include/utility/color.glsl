#if !defined UTILITY_COLOR_INCLUDED
#define UTILITY_COLOR_INCLUDED

// Rec. 709 (sRGB primaries)
const mat3 xyz_to_rec709 = mat3(
	 3.2406, -1.5372, -0.4986,
	-0.9689,  1.8758,  0.0415,
	 0.0557, -0.2040,  1.0570
);
const mat3 rec709_to_xyz = mat3(
	 0.4124,  0.3576,  0.1805,
	 0.2126,  0.7152,  0.0722,
	 0.0193,  0.1192,  0.9505
);

// Rec. 2020 (working color space)
// Big thanks to RRe36 for lending me these matrices
const mat3 xyz_to_rec2020 = mat3(
	 1.7166084, -0.3556621, -0.2533601,
	-0.6666829,  1.6164776,  0.0157685,
	 0.0176422, -0.0427763,  0.94222867
);
const mat3 rec2020_to_xyz = mat3(
	 0.6369736, 0.1446172, 0.1688585,
	 0.2627066, 0.6779996, 0.0592938,
	 0.0000000, 0.0280728, 1.0608437
);

const mat3 rec709_to_rec2020 = rec709_to_xyz * xyz_to_rec2020;
const mat3 rec2020_to_rec709 = rec2020_to_xyz * xyz_to_rec709;

const vec3 luminanceWeightsRec709  = vec3(0.2126, 0.7152, 0.0722);
const vec3 luminanceWeightsRec2020 = vec3(0.2627, 0.6780, 0.0593);
const vec3 luminanceWeightsAp1     = vec3(0.2722, 0.6741, 0.0537);

const vec3 primaryWavelengthsRec709 = vec3(660.0, 550.0, 440.0);
const vec3 primaryWavelengthsAp1    = vec3(630.0, 530.0, 465.0);

// nice little macro to convert color constants from sRGB to linear rec. 2020 (don't use for variables, as srgbToLinear is faster than pow)
#define toRec2020(srgb) pow(srgb, vec3(2.2)) * rec709_to_rec2020

float getLuminance(vec3 rgb, vec3 luminanceWeights) {
	return dot(rgb, luminanceWeights);
}

float getLuminance(vec3 rgb) {
	return getLuminance(rgb, luminanceWeightsRec2020);
}

// from Jodie
vec3 linearToSrgb(vec3 linear){
    return 1.14374 * (-0.126893 * linear + sqrt(linear));
}
// from https://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
vec3 srgbToLinear(vec3 srgb) {
	return srgb * (srgb * (srgb * 0.305306011 + 0.682171111) + 0.012522878);
}

// from https://gist.github.com/983/e170a24ae8eba2cd174f
vec3 rgbToHsl(vec3 c) {
	const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);

	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1e-6;

	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hslToRgb(vec3 c) {
	const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);

	c.yz = clamp01(c.yz);

	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);

	return c.z * mix(K.xxx, clamp01(p - K.xxx), c.y);
}

// from https://en.wikipedia.org/wiki/YCoCg#Conversion_with_the_RGB_color_model
vec3 rgbToYcocg(vec3 rgb) {
	const mat3 cm = mat3(
		 0.25,  0.5,   0.25,
		 0.5,   0.0,  -0.5,
		-0.25,  0.5,  -0.25
	);
	return rgb * cm;
}
vec3 ycocgToRgb(vec3 ycocg) {
	float tmp = ycocg.x - ycocg.z;
	return vec3(tmp + ycocg.y, ycocg.x + ycocg.z, tmp - ycocg.y);
}

// Original source: https://github.com/Jessie-LC/open-source-utility-code/blob/main/advanced/blackbody.glsl
vec3 blackbody(float temperature) {
	const vec3 lambda  = primaryWavelengthsAp1;
	const vec3 lambda2 = lambda * lambda;
	const vec3 lambda5 = lambda2 * lambda2 * lambda;

	const float h = 6.63e-16; // Planck constant
	const float k = 1.38e-5;  // Boltzmann constant
	const float c = 3.0e17;   // Speed of light

	const vec3 a = lambda5 / (2.0 * h * c * c);
	const vec3 b = (h * c) / (k * lambda);
	vec3 d = exp(b / temperature);

	vec3 rgb = a * d - a;
	return minOf(rgb) / rgb;
}

// Isolate a range of hues
float isolateHue(vec3 hsl, float center, float width) {
	if (hsl.y < 1e-2 || hsl.z < 1e-2) return 0.0; // black/gray colors with no hue
	return pulse(hsl.x * 360.0, center, width, 360.0);
}

#endif // UTILITY_COLOR_INCLUDED
