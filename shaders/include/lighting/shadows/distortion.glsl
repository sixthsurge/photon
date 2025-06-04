#if !defined INCLUDE_LIGHTING_DISTORTION
#define INCLUDE_LIGHTING_DISTORTION

#include "/include/utility/fast_math.glsl"

// Euclidian distance is defined as sqrt(a^2 + b^2 + ...). This function instead does
// quartic_root(a^4 + b^4 + ...). This results in smaller distances along the diagonal axes
float quartic_length(vec2 v) {
	return sqrt(sqrt(pow4(v.x) + pow4(v.y)));
}

float get_distortion_factor(vec2 shadow_clip_pos) {
	return quartic_length(shadow_clip_pos) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec3 distort_shadow_space(vec3 shadow_clip_pos, float distortion_factor) {
	return shadow_clip_pos * vec3(vec2(rcp(distortion_factor)), SHADOW_DEPTH_SCALE);
}

vec3 distort_shadow_space(vec3 shadow_clip_pos) {
	float distortion_factor = get_distortion_factor(shadow_clip_pos.xy);
	return distort_shadow_space(shadow_clip_pos, distortion_factor);
}

vec3 undistort_shadow_space(vec3 shadow_clip_pos) {
	shadow_clip_pos.xy *= (1.0 - SHADOW_DISTORTION) / (1.0 - quartic_length(shadow_clip_pos.xy));
	shadow_clip_pos.z  *= rcp(SHADOW_DEPTH_SCALE);
	return shadow_clip_pos;
}

// Shadow bias method from Complementary Reimagined by Emin 
// Many thanks to Emin for letting me use it <3
// https://www.complementary.dev/reimagined
vec3 get_shadow_bias(vec3 scene_pos, vec3 normal, float NoL, float skylight) {
#if defined WORLD_END
	skylight = 1.0;
#endif

	// Shadow bias without peter-panning
	return 0.25 * normal * clamp01(0.12 + 0.01 * length(scene_pos)) * (2.0 - clamp01(NoL));
}

#endif // INCLUDE_LIGHTING_DISTORTION
