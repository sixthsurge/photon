// Enable half-precision floating point types

#ifdef USE_HALF_PRECISION_FP
	#if defined MC_GL_AMD_gpu_shader_half_float 
		#extension GL_AMD_gpu_shader_half_float : enable
		#define HAS_F16
	#elif defined MC_GL_NV_gpu_shader5 
		#extension GL_NV_gpu_shader5 : enable
		#define HAS_F16
	#endif
#endif

#ifdef HAS_F16 
	#define f16       float16_t
#else 
	#define f16       float
	#define f16vec2   vec2 
	#define f16vec3   vec3 
	#define f16vec4   vec4 
	#define f16mat2   mat2 
	#define f16mat2x2 mat2x2
	#define f16mat2x3 mat2x3
	#define f16mat2x4 mat2x4
	#define f16mat3   mat3 
	#define f16mat3x2 mat3x2
	#define f16mat3x3 mat3x3
	#define f16mat3x4 mat3x4
	#define f16mat4   mat4 
	#define f16mat4x2 mat4x2
	#define f16mat4x3 mat4x3
	#define f16mat4x4 mat4x4
#endif

// Settings

#include "/settings.glsl"
 
// Compatibility fixes

#if MC_VERSION < 11700
	#define gtexture tex
#endif

#ifndef MC_GL_VENDOR_INTEL
	#define attribute in
#endif

// Common constants

const float eps          = 1e-6;
const float e            = exp(1.0);
const float pi           = acos(-1.0);
const float tau          = 2.0 * pi;
const float half_pi      = 0.5 * pi;
const float rcp_pi       = 1.0 / pi;
const float degree       = tau / 360.0; // Size of one degree in radians, useful because radians() is not a constant expression on all platforms
const float golden_ratio = 0.5 + 0.5 * sqrt(5.0);
const float golden_angle = tau / golden_ratio / golden_ratio;
const float hand_depth   = 0.56;

#if defined TAA && defined TAAU
const float taau_render_scale = TAAU_RENDER_SCALE;
#else
const float taau_render_scale = 1.0;
#endif

// Helper functions

#define rcp(x) (1.0 / (x))
#define clamp01(x) clamp(x, 0.0, 1.0) // free on operation output
#define max0(x) max(x, 0.0)
#define min1(x) min(x, 1.0)

float sqr(float x) { return x * x; }
vec2  sqr(vec2  v) { return v * v; }
vec3  sqr(vec3  v) { return v * v; }
vec4  sqr(vec4  v) { return v * v; }

float cube(float x) { return x * x * x; }

float max_of(vec2 v) { return max(v.x, v.y); }
float max_of(vec3 v) { return max(v.x, max(v.y, v.z)); }
float max_of(vec4 v) { return max(v.x, max(v.y, max(v.z, v.w))); }
float min_of(vec2 v) { return min(v.x, v.y); }
float min_of(vec3 v) { return min(v.x, min(v.y, v.z)); }
float min_of(vec4 v) { return min(v.x, min(v.y, min(v.z, v.w))); }

float length_squared(vec2 v) { return dot(v, v); }
float length_squared(vec3 v) { return dot(v, v); }

vec2 normalize_safe(vec2 v) { return v == vec2(0.0) ? v : normalize(v); }
vec3 normalize_safe(vec3 v) { return v == vec3(0.0) ? v : normalize(v); }

// Remapping functions

float linear_step(float edge0, float edge1, float x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}
float linear_step_unclamped(float edge0, float edge1, float x) {
	return (x - edge0) / (edge1 - edge0);
}

vec2 linear_step(vec2 edge0, vec2 edge1, vec2 x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}

// Can be used similarly to sqrt() to shape a signal on [0, 1]
float dampen(float x) {
	x = clamp01(x);
	return x * (2.0 - x);
}

// Can be used similarly to pow() to shape a signal
//
// amount := lifting amount [-1.0, inf]
//
// amount = 0 -> identity
// amount < 0 -> increase signal contrast (power > 1)
// amount > 0 -> reduce signal contrast (power < 1)
float lift(float x, float amount) {
	return (x + x * amount) / (1.0 + x * amount);
}
vec3 lift(vec3 x, float amount) {
	return (x + x * amount) / (1.0 + x * amount);
}

// Smoothing function used by smoothstep
// Zero derivative at zero and one
float cubic_smooth(float x) {
	return sqr(x) * (3.0 - 2.0 * x);
}
vec2 cubic_smooth(vec2 x) {
	return sqr(x) * (3.0 - 2.0 * x);
}

// Similar to the above, but even smoother with a zero second derivative at zero and one
float quintic_smooth(float x) {
    return cube(x) * (x * (x * 6.0 - 15.0) + 10.0);
}

// Converts between the unit range [0, 1] and texture coordinates on [0.5/res, 1 - 0.5/res]. This
// prevents extrapolation at texture edges (used for atmosphere lookup tables)
float get_uv_from_unit_range(float values, const int res) {
	return values * (1.0 - 1.0 / float(res)) + (0.5 / float(res));
}

float get_unit_range_from_uv(float uv, const int res) {
	return (uv - 0.5 / float(res)) / (1.0 - 1.0 / float(res));
}

// (the following functions are from https://iquilezles.org/articles/functions/)

// Applies a smooth minimum value to a signal, where n is the new minimum value and m is the
// threshold after which x remains unchanged
float almost_identity(float x, float m, float n) {
	if(x > m) return x;

	float a = 2.0 * n - m;
	float b = 2.0 * m - 3.0 * n;
	float t = x / m;

	return (a * t + b) * t * t + n;
}

// Equivalent to almost_identity with n = 0 and m = 1
float almost_unit_identity(float x) {
	return x * x * (2.0 - x);
}

// Remaps center +/- 0.5 * width to zero and center to 1, with the same smoothing function as
// smoothstep
float pulse(float x, float center, float width) {
    x = abs(x - center) / width;
    return x > 1.0 ? 0.0 : 1.0 - cubic_smooth(x);
}

float pulse(float x, float center, float width, const float period) {
	x = (x - center + 0.5 * period) / period;
	x = fract(x) * period - (0.5 * period);

	return pulse(x, 0.0, width);
}

// Exponential impulse function, for when a signal rises quickly then gradually falls.
float impulse(float x, float peak) {
	float h = peak * x;
	return h * exp(1.0 - h);
}

// Euclidian distance is defined as sqrt(a^2 + b^2 + ...). This function instead does
// cbrt(|a|^3 + |b|^3 + ...). This results in smaller distances along the diagonal axes
float cubic_length(vec2 v) {
	return pow(cube(abs(v.x)) + cube(abs(v.y)), rcp(3.0));
}

// Matrix operations

vec2 diagonal(mat2 m) { return vec2(m[0].x, m[1].y); }
vec3 diagonal(mat3 m) { return vec3(m[0].x, m[1].y, m[2].z); }
vec4 diagonal(mat4 m) { return vec4(m[0].x, m[1].y, m[2].z, m[3].w); }

vec3 transform(mat4 m, vec3 pos) {
    return mat3(m) * pos + m[3].xyz;
}

vec4 project(mat4 m, vec3 pos) {
    return vec4(m[0].x, m[1].y, m[2].zw) * pos.xyzz + m[3];
}

vec3 project_and_divide(mat4 m, vec3 pos) {
    vec4 homogenous = project(m, pos);
    return homogenous.xyz / homogenous.w;
}

vec3 project_ortho(mat4 m, vec3 pos) {
    return diagonal(m).xyz * pos + m[3].xyz;
}

// Hand 

void fix_hand_depth(inout float depth, out bool is_hand) {
	is_hand = depth < hand_depth; // NB: Not the same as mc_hand_depth
	if (is_hand) {
		depth  = depth * 2.0 - 1.0;
		depth *= rcp(MC_HAND_DEPTH);
		depth  = depth * 0.5 + 0.5;
	}
}
void fix_hand_depth(inout float depth) {
	bool unused;
	fix_hand_depth(depth, unused);
}
