#if !defined INCLUDE_FRAGMENT_RAYTRACER
#define INCLUDE_FRAGMENT_RAYTRACER

#include "/include/utility/geometry.glsl"
#include "/include/utility/spaceConversion.glsl"

bool raytraceIntersection(
	sampler2D depthSampler,
	vec3 screenPos,
	vec3 viewPos,
	vec3 viewDir,
	float dither,
	const uint maxIntersectionStepCount,
	const uint refinementStepCount,
	out vec3 hitPos
) {
	if (viewDir.z > 0.0 && viewDir.z >= -viewPos.z) return false;
	vec3 screenDir = normalize(viewToScreenSpace(viewPos + viewDir, true) - screenPos);

	float rayLength = intersectBox(screenPos, screenDir, mat2x3(vec3(0.0, 0.0, handDepth), vec3(1.0))).y;
	uint intersectionStepCount = uint(float(maxIntersectionStepCount) * (dampen(clamp01(rayLength)) * 0.5 + 0.5));

	float stepLength = rayLength * rcp(float(intersectionStepCount));

	vec3 rayStep = screenDir * stepLength;
	vec3 rayPos = screenPos + dither * rayStep;

	float depthTolerance = 0.002; // Todo: better depth tolerance calculation

	bool hit = false;

	//--// Intersection loop

	for (int i = 0; i < intersectionStepCount; ++i, rayPos += rayStep) {
		float depth = texelFetch(depthSampler, ivec2(rayPos.xy * viewSize), 0).x;

		if (depth < rayPos.z && abs(depthTolerance - (rayPos.z - depth)) < depthTolerance) {
			hit = true;
			hitPos = rayPos;
			break;
		}
	}

	if (!hit) return false;

	//--// Refinement loop

	for (int i = 0; i < refinementStepCount; ++i) {
		rayStep *= 0.5;

		float depth = texelFetch(depthSampler, ivec2(hitPos.xy * viewSize), 0).x;

		if (depth < hitPos.z && abs(depthTolerance - (hitPos.z - depth)) < depthTolerance) {
			hitPos -= rayStep;
		} else {
			hitPos += rayStep;
		}
	}

	return true;
}

#endif // INCLUDE_FRAGMENT_RAYTRACER
