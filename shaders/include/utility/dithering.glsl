#if !defined INCLUDE_UTILITY_DITHERING
#define INCLUDE_UTILITY_DITHERING

float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4 (vec2 a) { return 0.25 * bayer2 (0.5 * a) + bayer2(a); }
float bayer8 (vec2 a) { return 0.25 * bayer4 (0.5 * a) + bayer2(a); }
float bayer16(vec2 a) { return 0.25 * bayer8 (0.5 * a) + bayer2(a); }
float bayer32(vec2 a) { return 0.25 * bayer16(0.5 * a) + bayer2(a); }

float interleaved_gradient_noise(vec2 pos) {
	return fract(52.9829189 * fract(0.06711056 * pos.x + (0.00583715 * pos.y)));
}

float interleaved_gradient_noise(vec2 pos, int t) {
	return interleaved_gradient_noise(pos + 5.588238 * (t & 63));
}

float dither_8bit(float x, float pattern) {
	const vec2 mul_add = vec2(1.0, -0.5) / 255.0;
	return clamp01(x + (pattern * mul_add.x + mul_add.y));
}

vec2 dither_8bit(vec2 x, float pattern) {
	const vec2 mul_add = vec2(1.0, -0.5) / 255.0;
	return clamp01(x + (pattern * mul_add.x + mul_add.y));
}

vec3 dither_8bit(vec3 rgb, float pattern) {
	const vec2 mul_add = vec2(1.0, -0.5) / 255.0;
	return clamp01(rgb + (pattern * mul_add.x + mul_add.y));
}

#endif // INCLUDE_UTILITY_DITHERING
