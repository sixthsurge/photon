#if !defined INCLUDE_FRAGMENT_WATERNORMAL
#define INCLUDE_FRAGMENT_WATERNORMAL

#include "/include/utility/spaceConversion.glsl"

float getWaterHeight(vec2 coord) {
	float frequency = 0.009;
	float amplitude = 1.0;
	float height = 0.0;
	float t = frameTimeCounter;

	float amplitudeSum = 0.0;

	float angle = 0.2;

	for (int i = 0; i < 3; ++i) {
		vec2 dir = vec2(cos(angle), sin(angle));
		height += texture(noisetex, coord * frequency + 0.005 * t * exp2(i) * dir).y * amplitude;
		amplitudeSum += amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
		angle += 2.4;
	}

	return height / amplitudeSum;
}

vec3 getWaterNormal(vec3 geometryNormal, vec3 worldPos) {
	vec2 coord = worldPos.xz - worldPos.y;

	const float h = 0.1;
	float wave0 = getWaterHeight(coord);
	float wave1 = getWaterHeight(coord + vec2(h, 0.0));
	float wave2 = getWaterHeight(coord + vec2(0.0, h));

	float normalInfluence  = 0.15 * smoothstep(0.0, 0.05, abs(geometryNormal.y));
	      normalInfluence *= smoothstep(0.0, 0.1, abs(dot(geometryNormal, normalize(worldPos - cameraPosition)))); // prevent noise when looking horizontal

	vec3 normal     = vec3(wave1 - wave0, wave2 - wave0, h);
	     normal.xy *= normalInfluence;

	return normalize(normal);
}

vec2 waterParallax(vec3 tangentDir, vec2 coord) {
	const int stepCount = 4;
	const float parallaxScale = 1.0;

	vec2 rayStep = tangentDir.xy * rcp(-tangentDir.z) * parallaxScale * rcp(float(stepCount));

	float depthValue = getWaterHeight(coord);
	float depthMarch = 0.0;
	float depthPrevious;

	while (depthMarch < depthValue) {
		depthPrevious = depthValue;
		coord += rayStep;
		depthValue = getWaterHeight(coord);
		depthMarch += rcp(float(stepCount));
	}

	// Interpolation step
	float depthBefore = depthPrevious - depthMarch + rcp(float(stepCount));
	float depthAfter  = depthValue - depthMarch;
	return mix(coord, coord - rayStep, depthAfter / (depthAfter - depthBefore));
}

#endif // INCLUDE_FRAGMENT_WATERNORMAL
