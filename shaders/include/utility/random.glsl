#if !defined INCLUDE_UTILITY_RANDOM
#define INCLUDE_UTILITY_RANDOM

// http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/

const float phi1 = 1.6180339887; // Golden ratio, solution to x^2 = x + 1
const float phi2 = 1.3247179572; // Plastic constant, solution to x^3 = x + 1
const float phi3 = 1.2207440846; // Solution to x^4 = x + 1

float r1(int n, float seed) {
    const float alpha = 1.0 / phi1;
	return fract(seed + n * alpha);
}
float r1(int n) {
	return r1(n, 0.5);
}
float r1_next(float u) {
    const float alpha = 1.0 / phi1;
	return fract(u + alpha);
}

vec2 r2(int n, vec2 seed) {
    const vec2 alpha = 1.0 / vec2(phi2, phi2 * phi2);
	return fract(seed + n * alpha);
}
vec2 r2(int n) {
	return r2(n, vec2(0.5));
}
vec2 r2_next(vec2 u) {
    const vec2 alpha = 1.0 / vec2(phi2, phi2 * phi2);
    return fract(u + alpha);
}

vec3 r3(int n, vec3 seed) {
    const vec3 alpha = 1.0 / vec3(phi3, phi3 * phi3, phi3 * phi3 * phi3);
	return fract(seed + n * alpha);
}
vec3 r3(int n) {
	return r3(n, vec3(0.5));
}
vec3 r3_next(vec3 u) {
    const vec3 alpha = 1.0 / vec3(phi3, phi3 * phi3, phi3 * phi3 * phi3);
	return fract(u + alpha);
}

//----------------------------------------------------------------------------//

// https://nullprogram.com/blog/2018/07/31/

uint lowbias32(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

uint lowbias32_inverse(uint x) {
    x ^= x >> 16;
    x *= 0x43021123u;
    x ^= x >> 15 ^ x >> 30;
    x *= 0x1d69e2a5u;
    x ^= x >> 16;
    return x;
}

float rand_next_float(inout uint state) {
    state = lowbias32(state);
    return float(state) / float(0xffffffffu);
}

vec2 rand_next_vec2(inout uint state) { return vec2(rand_next_float(state), rand_next_float(state)); }
vec3 rand_next_vec3(inout uint state) { return vec3(rand_next_float(state), rand_next_float(state), rand_next_float(state)); }
vec4 rand_next_vec4(inout uint state) { return vec4(rand_next_float(state), rand_next_float(state), rand_next_float(state), rand_next_float(state)); }

//----------------------------------------------------------------------------//

// https://www.shadertoy.com/view/4dj_s_r_w
// Uncomment when needed

//*
float hash1(float p) {
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
//*/

/*
float hash1(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
//*/

//*
float hash1(vec3 p3) {
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}
//*/

/*
vec2 hash2(float p) {
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}
//*/

//*
vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}
//*/

//*
vec2 hash2(vec3 p3) {
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}
//*/

/*
vec3 hash3(float p) {
   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
   p3 += dot(p3, p3.yzx+33.33);
   return fract((p3.xxy+p3.yzz)*p3.zyx);
}
//*/

/*
vec3 hash3(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}
//*/

/*
vec3 hash3(vec3 p3) {
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);

}
//*/

/*
vec4 hash4(float p) {
	vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}
//*/

//*
vec4 hash4(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}
//*/

//*
vec4 hash4(vec3 p) {
	vec4 p4 = fract(vec4(p.xyzx)  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}
//*/

/*
vec4 hash4(vec4 p4) {
	p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}
//*/

//----------------------------------------------------------------------------//

// One dimensional value noise
float noise_1d(float x) {
	float i, f = modf(x, i);
	f = cubic_smooth(f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

#endif // INCLUDE_UTILITY_RANDOM
