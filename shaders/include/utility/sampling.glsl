#if !defined INCLUDE_UTILITY_SAMPLING
#define INCLUDE_UTILITY_SAMPLING

vec2 vogelDiskSample(int stepIndex, int stepCount, float rotation) {
	const float goldenAngle = 2.4;

	float r = sqrt(stepIndex + 0.5) / sqrt(float(stepCount));
	float theta = stepIndex * goldenAngle + rotation;

	return r * vec2(cos(theta), sin(theta));
}

vec3 uniformSphereSample(vec2 hash) {
	hash.x *= tau; hash.y = 2.0 * hash.y - 1.0;
	return vec3(vec2(sin(hash.x), cos(hash.x)) * sqrt(1.0 - hash.y * hash.y), hash.y);
}

vec3 uniformHemisphereSample(vec3 vector, vec2 hash) {
	vec3 dir = uniformSphereSample(hash);
	return dot(dir, vector) < 0.0 ? -dir : dir;
}

// https://amietia.com/lambertnotangent.html
vec3 cosineWeightedHemisphereSample(vec3 vector, vec2 hash) {
	vec3 dir = normalize(uniformSphereSample(hash) + vector);
	return dot(dir, vector) < 0.0 ? -dir : dir;
}

#endif // INCLUDE_UTILITY_SAMPLING
