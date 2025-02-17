#if !defined INCLUDE_UTILITY_SLERP
#define INCLUDE_UTILITY_SLERP

#include "/include/utility/fast_math.glsl"

// Spherical linear interpolation of two unit vectors
vec3 slerp(vec3 v0, vec3 v1, float t) {
	float cos_theta = dot(v0, v1);
	if (cos_theta > 0.999) return v0;

	float theta = fast_acos(cos_theta);
	float rcp_sin_theta = rcp(sin(theta));
	
	float w0 = rcp_sin_theta * sin((1.0 - t) * theta);
	float w1 = rcp_sin_theta * sin(t * theta);

	return v0 * w0 + v1 * w1;
}

#endif // INCLUDE_UTILITY_SLERP
