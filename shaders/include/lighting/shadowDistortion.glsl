#if !defined INCLUDE_LIGHTING_SHADOWDISTORTION
#define INCLUDE_LIGHTING_SHADOWDISTORTION

#include "/include/utility/fastMath.glsl"

// Euclidian distance is defined as sqrt(a^2 + b^2 + ...). This function instead does
// quarticRoot(a^4 + b^4 + ...). This results in smaller distances along the diagonal axes
float quarticLength(vec2 v) {
	return sqrt(sqrt(pow4(v.x) + pow4(v.y)));
}

float getShadowDistortionFactor(vec2 positionShadowClip) {
	return quarticLength(positionShadowClip) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec3 distortShadowSpace(vec3 positionShadowClip, float distortionFactor) {
	return positionShadowClip * vec3(vec2(rcp(distortionFactor)), SHADOW_DEPTH_SCALE);
}

vec3 distortShadowSpace(vec3 positionShadowClip) {
	float distortionFactor = getShadowDistortionFactor(positionShadowClip.xy);
	return distortShadowSpace(positionShadowClip, distortionFactor);
}

vec3 undistortShadowSpace(vec3 positionShadowClip) {
	positionShadowClip.xy *= (1.0 - SHADOW_DISTORTION) / (1.0 - quarticLength(positionShadowClip.xy));
	positionShadowClip.z  *= rcp(SHADOW_DEPTH_SCALE);
	return positionShadowClip;
}

#endif // INCLUDE_LIGHTING_SHADOWDISTORTION
