#if !defined INCLUDE_UTILITY_COLOR
#define INCLUDE_UTILITY_COLOR

const vec3 luminanceWeightsR709   = vec3(0.2126, 0.7152, 0.0722);
const vec3 luminanceWeightsAp1    = vec3(0.2722, 0.6741, 0.0537);

const vec3 primaryWavelengthsR709 = vec3(660.0, 550.0, 440.0);
const vec3 primaryWavelengthsAp1  = vec3(630.0, 530.0, 465.0); // from RRe36

const mat3 r709ToXyz = mat3(
	 0.4124,  0.3576,  0.1805,
	 0.2126,  0.7152,  0.0722,
	 0.0193,  0.1192,  0.9505
);
const mat3 xyzToR709 = mat3(
	 3.2406, -1.5372, -0.4986,
	-0.9689,  1.8758,  0.0415,
	 0.0557, -0.2040,  1.0570
);

float getLuminance(vec3 rgb, vec3 luminanceWeights) {
	return dot(rgb, luminanceWeights);
}

float getLuminance(vec3 rgb) {
	return getLuminance(rgb, luminanceWeightsAp1);
}

// Source: https://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
vec3 linearToSrgb(vec3 linear){
    return 1.14374 * (-0.126893 * linear + sqrt(linear));
}
vec3 srgbToLinear(vec3 srgb) {
	return srgb * (srgb * (srgb * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 rgbToHsl(vec3 rgb) {
	float h, s, l;

	float minComponent = minOf(rgb);
	float maxComponent = maxOf(rgb);

	l = 0.5 * (minComponent + maxComponent);

	if (minComponent == maxComponent) { // no saturation
		h = 0.0;
		s = 0.0;
	} else {
		float chroma = maxComponent - minComponent;

		s = chroma / (1.0 - abs(l * 2.0 - 1.0));
		s = clamp01(s);

		if (rgb.r == maxComponent)
			h = (rgb.g - rgb.b) / chroma;
		else if (rgb.g == maxComponent)
			h = 2.0 + (rgb.b - rgb.r) / chroma;
		else
			h = 4.0 + (rgb.r - rgb.g) / chroma;

		h  = h < 0.0 ? h + 6.0 : h;
		h *= 60.0;
	}

	return vec3(h, s, l);
}

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

// Isolate a range of hues
float pulseHue(float hue, float center, float width) {
	hue = (hue - center + 180.0) * rcp(360.0);
	hue = fract(hue) * 360.0 - 180.0;

	return pulse(hue, 0.0, width);
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

#endif // INCLUDE_UTILITY_COLOR
