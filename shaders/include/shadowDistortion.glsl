#if !defined SHADOWDISTORTION_INCLUDED
#define SHADOWDISTORTION_INCLUDED

#include "/include/utility/fastMath.glsl"

#define SHADOW_DEPTH_SCALE 0.2
#define SHADOW_DISTORTION 0.85

// Euclidian distance is defined as sqrt(a^2 + b^2 + ...). This function instead does
// quarticRoot(a^4 + b^4 + ...). This results in smaller distances along the diagonal axes
float quarticLength(vec2 v) {
	return sqrt(sqrt(pow4(v.x) + pow4(v.y)));
}

float getShadowDistortionFactor(vec2 shadowClipPos) {
	return quarticLength(shadowClipPos) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec3 distortShadowSpace(vec3 shadowClipPos, float distortionFactor) {
	return shadowClipPos * vec3(vec2(rcp(distortionFactor)), SHADOW_DEPTH_SCALE);
}

vec3 distortShadowSpace(vec3 shadowClipPos) {
	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);
	return distortShadowSpace(shadowClipPos, distortionFactor);
}

vec3 undistortShadowSpace(vec3 shadowClipPos) {
	shadowClipPos.xy *= (1.0 - SHADOW_DISTORTION) / (1.0 - quarticLength(shadowClipPos.xy));
	shadowClipPos.z  *= rcp(SHADOW_DEPTH_SCALE);
	return shadowClipPos;
}

// Shadow bias method from Complementary Reimagined by Emin (fully fixes peter panning
// and light leaking underground!)
// Many thanks to Emin for letting me use it <3
// https://www.complementary.dev/reimagined
vec3 getShadowBias(vec3 scenePos, vec3 normal, float NoL, float skylight) {
	// Shadow bias without peter-panning
	vec3 bias = 0.25 * normal * clamp01(0.12 + 0.01 * length(scenePos)) * (2.0 - clamp01(NoL));

	// Fix light leaking in caves
	vec3 edgeFactor = 0.1 - 0.2 * fract(scenePos + cameraPosition + normal * 0.01);

	return bias + edgeFactor * clamp01(1.0 - pow4(skylight));
}

#endif // SHADOWDISTORTION_INCLUDED
