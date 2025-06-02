#if !defined INCLUDE_UTILITY_COLOR
#define INCLUDE_UTILITY_COLOR

const vec3 luminance_weights_rec709  = vec3(0.2126, 0.7152, 0.0722);
const vec3 luminance_weights_rec2020 = vec3(0.2627, 0.6780, 0.0593);
const vec3 luminance_weights_ap1     = vec3(0.2722, 0.6741, 0.0537);
#define luminance_weights luminance_weights_rec2020

// closest wavelengths to RGB primaries
const vec3 primary_wavelengths_rec709  = vec3(660.0, 550.0, 440.0);
const vec3 primary_wavelengths_rec2020 = vec3(660.0, 550.0, 440.0);
const vec3 primary_wavelengths_ap1     = vec3(630.0, 530.0, 465.0);
#define primary_wavelengths primary_wavelengths_rec2020

// -----------------------------------
//   Color space conversion matrices
// -----------------------------------

#define display_to_working_color rec709_to_rec2020
#define working_to_display_color rec2020_to_rec709
#define rec709_to_working_color  rec709_to_rec2020

// Helper macro to convert sRGB colors to working space
#define from_srgb(x) (pow(x, vec3(2.2)) * rec709_to_rec2020)

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

// ------------------------------
//   Transfer functions (gamma)
// ------------------------------

#define display_eotf srgb_eotf
#define display_eotf_inv srgb_eotf_inv

vec3 srgb_eotf(vec3 linear) { // linear -> sRGB
    return 1.14374 * (-0.126893 * linear + sqrt(linear)); // from Jodie in #snippets
}
vec3 srgb_eotf_inv(vec3 srgb) { // sRGB -> linear
	return srgb * (srgb * (srgb * 0.305306011 + 0.682171111) + 0.012522878); // https://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
}

// -------------------------------------------------
//   Transformations between color representations
// -------------------------------------------------

// RGB <-> HSL

// from https://gist.github.com/983/e170a24ae8eba2cd174f
vec3 rgb_to_hsl(vec3 c) {
	const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);

	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1e-6;

	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsl_to_rgb(vec3 c) {
	const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);

	c.yz = clamp01(c.yz);

	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);

	return c.z * mix(K.xxx, clamp01(p - K.xxx), c.y);
}

// RGB <-> YCoCg

// from https://en.wikipedia.org/wiki/YCoCg#Conversion_with_the_RGB_color_model
vec3 rgb_to_ycocg(vec3 rgb) {
	const mat3 cm = mat3(
		 0.25,  0.5,   0.25,
		 0.5,   0.0,  -0.5,
		-0.25,  0.5,  -0.25
	);
	return rgb * cm;
}
vec3 ycocg_to_rgb(vec3 ycocg) {
	float tmp = ycocg.x - ycocg.z;
	return vec3(tmp + ycocg.y, ycocg.x + ycocg.z, tmp - ycocg.y);
}

// XYZ <-> LAB

float cie_lab_f(float t) {
	const float delta = 6.0 / 29.0;

	if (t > cube(delta)) {
		return pow(t, rcp(3.0));
	} else {
		return rcp(3.0 * delta * delta) * t + (4.0 / 29.0);
	}
}
float cie_lab_f_inv(float t) {
	const float delta = 6.0 / 29.0;

	if (t > delta) {
		return cube(t);
	} else {
		return (3.0 * delta * delta) * (t - (4.0 / 29.0));
	}
}

vec3 xyz_to_lab(vec3 xyz) {
	const vec3 xyz_n = vec3(95.0489, 100.0, 108.8840);

	xyz /= xyz_n;

	vec3 f = vec3(
		cie_lab_f(xyz.x),
		cie_lab_f(xyz.y),
		cie_lab_f(xyz.z)
	);

	return vec3(
		116.0 * f.y - 16.0,
		500.0 * (f.x - f.y),
		200.0 * (f.y - f.z)
	);
}
vec3 lab_to_xyz(vec3 lab) {
	const vec3 xyz_n = vec3(95.0489, 100.0, 108.8840);

	float y = lab.x * rcp(116.0) + (16.0 / 116.0);

	vec3 f_inv = vec3(
		cie_lab_f_inv(y + lab.y * rcp(500.0)),
		cie_lab_f_inv(y),
		cie_lab_f_inv(y - lab.z * rcp(200.0))
	);

	return xyz_n * f_inv;
}

// Original source: https://github.com/Jessie-LC/open-source-utility-code/blob/main/advanced/blackbody.glsl
vec3 blackbody(float temperature) {
	const vec3 lambda  = primary_wavelengths_rec2020;
	const vec3 lambda2 = lambda * lambda;
	const vec3 lambda5 = lambda2 * lambda2 * lambda;

	const float h = 6.63e-16; // Planck constant
	const float k = 1.38e-5;  // Boltzmann constant
	const float c = 3.0e17;   // Speed of light

	const vec3 a = lambda5 / (2.0 * h * c * c);
	const vec3 b = (h * c) / (k * lambda);
	vec3 d = exp(b / temperature);

	vec3 rgb = a * d - a;
	return min_of(rgb) / rgb;
}

// Isolate a range of hues
float isolate_hue(vec3 hsl, float center, float width) {
	if (hsl.y < 1e-2 || hsl.z < 1e-2) return 0.0; // black/gray colors with no hue
	return pulse(hsl.x * 360.0, center, width, 360.0);
}

#endif // INCLUDE_UTILITY_COLOR
