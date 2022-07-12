#if !defined INCLUDE_FRAGMENT_RAYTRACER
#define INCLUDE_FRAGMENT_RAYTRACER

#include "/include/utility/spaceConversion.glsl"

bool raytraceIntersection(
	sampler2D depthSampler,
	vec3 rayOrigin,
	vec3 rayOriginView,
	vec3 rayDirView,
	float stepGrowth,
	float dither,
	const uint maxIntersectionSteps,
	const uint refinementSteps,
	const bool reversedZ,
	out vec3 hitPos
) {
	vec3 rayDirScreen = normalize(viewToScreenSpace(rayOriginView + rayDirView, true) - rayOrigin);

	float rayLength = (rayDirScreen.z < 0.0) ? rayOrigin.z - reverseLinearDepth(MC_HAND_DEPTH) : 1.0 - rayOrigin.z;
	      rayLength = clamp(abs(rayLength / rayDirScreen.z), 5e-2, 1.0);

	float stepLength = (stepGrowth == 1.0)
		? rcp(float(maxIntersectionSteps))
		: (stepGrowth - 1.0) / (pow(stepGrowth, float(maxIntersectionSteps)) - 1.0);

	bool hit = false;
	vec3 rayVector = rayDirScreen * rayLength;

	//--// Intersection loop

	for (float t = 0; t < 1.0; t += stepLength) {
		vec3 rayPos = rayOrigin + rayVector * (t + stepLength * stepGrowth * dither);

		if (clamp01(rayPos) != rayPos) return false;

		float depthTolerance = 0.002;

		float depth = texelFetch(depthSampler, ivec2(rayPos.xy * viewSize), 0).x;
		      depth = reversedZ ? 1.0 - depth : depth;

		if (depth < rayPos.z && abs(depthTolerance - (rayPos.z - depth)) < depthTolerance) {
			hit = true;
			hitPos = rayPos;
			break;
		}

		stepLength *= stepGrowth;
	}

	if (!hit) return false;

	//--// Refinement loop

	for (int i = 0; i < refinementSteps; ++i) {
		stepLength *= 0.5;

		float depthTolerance = 0.002;

		float depth = texelFetch(depthSampler, ivec2(hitPos.xy * viewSize), 0).x;
		      depth = reversedZ ? 1.0 - depth : depth;

		if (depth < hitPos.z && abs(depthTolerance - (hitPos.z - depth)) < depthTolerance) {
			hitPos -= rayVector * stepLength;
		} else {
			hitPos += rayVector * stepLength;
		}
	}

	return true;
}

#endif // INCLUDE_FRAGMENT_RAYTRACER
