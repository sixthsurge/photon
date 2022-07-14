#if !defined INCLUDE_FRAGMENT_WATERNORMAL
#define INCLUDE_FRAGMENT_WATERNORMAL

#include "/include/utility/spaceConversion.glsl"

float getWaterHeight(vec2 coord, vec2 flowDir) {
	const float directionalFlowSpeed = 1.5;

	bool directionalFlow = all(greaterThan(abs(flowDir), vec2(eps)));

	float frequency = 0.009;
	float amplitude = 1.0;
	float height = 0.0;
	float t = frameTimeCounter;

	float amplitudeSum = 0.0;

	float angle = 0.2;

	for (int i = 0; i < 3; ++i) {
		vec2 dir = directionalFlow ? -flowDir * directionalFlowSpeed : vec2(cos(angle), sin(angle));
		height += texture(noisetex, coord * frequency + 0.005 * t * exp2(i) * dir).y * amplitude;
		amplitudeSum += amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
		angle += 2.4;
	}

	return height / amplitudeSum;
}

vec3 getWaterNormal(vec3 geometryNormal, vec3 positionWorld, vec2 flowDir) {
	vec2 coord = positionWorld.xz - positionWorld.y;

	const float h = 0.1;
	float wave0 = getWaterHeight(coord, flowDir);
	float wave1 = getWaterHeight(coord + vec2(h, 0.0), flowDir);
	float wave2 = getWaterHeight(coord + vec2(0.0, h), flowDir);

	float normalInfluence  = 0.15 * smoothstep(0.0, 0.05, abs(geometryNormal.y));
	      normalInfluence *= smoothstep(0.0, 0.1, abs(dot(geometryNormal, normalize(positionWorld - cameraPosition)))); // prevent noise when looking horizontal

	vec3 normal     = vec3(wave1 - wave0, wave2 - wave0, h);
	     normal.xy *= normalInfluence;

	return normalize(normal);
}

vec2 waterParallax(vec3 viewerDirTangent, vec2 coord, vec2 flowDir) {
	const int stepCount = 4;
	const float parallaxScale = 1.0;

	vec2 rayStep = viewerDirTangent.xy * rcp(viewerDirTangent.z) * parallaxScale * rcp(float(stepCount));

	float depthValue = getWaterHeight(coord, flowDir);
	float depthMarch = 0.0;
	float depthPrevious;

	while (depthMarch < depthValue) {
		depthPrevious = depthValue;
		coord += rayStep;
		depthValue = getWaterHeight(coord, flowDir);
		depthMarch += rcp(float(stepCount));
	}

	// Interpolation step
	float depthBefore = depthPrevious - depthMarch + rcp(float(stepCount));
	float depthAfter  = depthValue - depthMarch;
	return mix(coord, coord - rayStep, depthAfter / (depthAfter - depthBefore));
}

#endif // INCLUDE_FRAGMENT_WATERNORMAL
