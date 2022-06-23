#if !defined INCLUDE_GLOBAL
#define INCLUDE_GLOBAL

//--// Settings //------------------------------------------------------------//

#include "/include/config.glsl"

//--// Constants //-----------------------------------------------------------//

const float eps         = 1e-6;
const float pi          = acos(-1.0);
const float tau         = 2.0 * pi;
const float rcpPi       = 1.0 / pi;
const float halfPi      = 0.5 * pi;
const float goldenRatio = 0.5 + 0.5 * sqrt(5.0);
const float goldenAngle = tau / goldenRatio / goldenRatio;

const float renderScale = inversesqrt(float(TAA_UPSCALING_FACTOR));

#ifndef MC_HAND_DEPTH
	#define MC_HAND_DEPTH 0.56
#endif

//--// Functions //-----------------------------------------------------------//

#define rcp(x) (1.0 / (x))
#define clamp01(x) clamp(x, 0.0, 1.0) // free on operation output
#define max0(x) max(x, 0.0)
#define min1(x) min(x, 1.0)

float sqr(float x) { return x * x; }
vec2  sqr(vec2  v) { return v * v; }
vec3  sqr(vec3  v) { return v * v; }
vec4  sqr(vec4  v) { return v * v; }

float cube(float x) { return x * x * x; }

float maxOf(vec2 v) { return max(v.x, v.y); }
float maxOf(vec3 v) { return max(v.x, max(v.y, v.z)); }
float maxOf(vec4 v) { return max(v.x, max(v.y, max(v.z, v.w))); }
float minOf(vec2 v) { return min(v.x, v.y); }
float minOf(vec3 v) { return min(v.x, min(v.y, v.z)); }
float minOf(vec4 v) { return min(v.x, min(v.y, min(v.z, v.w))); }

float lengthSquared(vec2 v) { return dot(v, v); }
float lengthSquared(vec3 v) { return dot(v, v); }

vec2 normalizeSafe(vec2 v) { return v == vec2(0.0) ? v : normalize(v); }
vec3 normalizeSafe(vec3 v) { return v == vec3(0.0) ? v : normalize(v); }

// Euclidian distance is defined as sqrt(a^2 + b^2 + ...). This function instead does
// cbrt(|a|^3 + |b|^3 + ...). This results in smaller distances along the diagonal axes
float cubicLength(vec2 v) {
	return pow(cube(abs(v.x)) + cube(abs(v.y)), rcp(3.0));
}

// Source: https://iquilezles.org/www/articles/texture/texture.htm
vec4 textureSmooth(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

//--// Remapping functions

float linearStep(float edge0, float edge1, float x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}

vec2 linearStep(vec2 edge0, vec2 edge1, vec2 x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}

float dampen(float x) {
	x = clamp01(x);
	return x * (2.0 - x); // faster than sqrt with a similar shape
}

// Smoothing function used by smoothstep
// Zero derivative at zero and one
float cubicSmooth(float x) {
	return sqr(x) * (3.0 - 2.0 * x);
}

// Similar to the above, but even smoother with a zero second derivative at zero and one
float quinticSmooth(float x) {
    return cube(x) * (x * (x * 6.0 - 15.0) + 10.0);
}

// Converts between the unit range [0, 1] and texture coordinates on [0.5/res, 1 - 0.5/res]. This
// prevents extrapolation at texture edges (used for atmosphere lookup tables)
float getTexCoordFromUnitRange(float values, const int res) {
	return values * (1.0 - 1.0 / float(res)) + (0.5 / float(res));
}
float getUnitRangeFromTexCoord(float uv, const int res) {
	return (uv - 0.5 / float(res)) / (1.0 - 1.0 / float(res));
}

// The following functions are from https://iquilezles.org/articles/functions/

// Applies a smooth minimum value to a signal, where n is the new minimum value and m is the
// threshold after which x remains unchanged
float almostIdentity(float x, float m, float n) {
	if(x > m) return x;

	float a = 2.0 * n - m;
	float b = 2.0 * m - 3.0 * n;
	float t = x / m;

	return (a * t + b) * t * t + n;
}

// Equivalent to almostIdentity with n = 0 and m = 1
float almostUnitIdentity(float x) {
	return x * x * (2.0 - x);
}

// Remaps center +/- 0.5 * width to zero and center to 1, with the same smoothing function as
// smoothstep
float pulse(float x, float center, float width) {
    x = abs(x - center) / width;
    return x > 1.0 ? 0.0 : 1.0 - cubicSmooth(x);
}

// Exponential impulse function, for when a signal rises quickly then gradually falls.
float impulse(float x, float peak) {
	float h = peak * x;
	return h * exp(1.0 - h);
}

//--// Matrix operations

vec2 diagonal(mat2 m) { return vec2(m[0].x, m[1].y); }
vec3 diagonal(mat3 m) { return vec3(m[0].x, m[1].y, m[2].z); }
vec4 diagonal(mat4 m) { return vec4(m[0].x, m[1].y, m[2].z, m[3].w); }

vec3 transform(mat4 m, vec3 pos) {
    return mat3(m) * pos + m[3].xyz;
}

vec4 project(mat4 m, vec3 pos) {
    return vec4(m[0].x, m[1].y, m[2].zw) * pos.xyzz + m[3];
}

vec3 projectAndDivide(mat4 m, vec3 pos) {
    vec4 homogenous = project(m, pos);
    return homogenous.xyz / homogenous.w;
}

vec3 projectOrtho(mat4 m, vec3 pos) {
    return diagonal(m).xyz * pos + m[3].xyz;
}

#endif // INCLUDE_GLOBAL
