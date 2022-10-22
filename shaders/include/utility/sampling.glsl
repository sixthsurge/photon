#if !defined UTILITY_SAMPLING_INCLUDED
#define UTILITY_SAMPLING_INCLUDED

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

// from https://jcgt.org/published/0007/04/01/paper.pdf: "Sampling the GGX distribution of visible normals"
vec3 sampleGgxVndf(vec3 viewerDir, vec2 alpha, vec2 hash) {
	// Section 3.2: transforming the view direction to the hemisphere configuration
	viewerDir = normalize(vec3(alpha * viewerDir.xy, viewerDir.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lenSq = lengthSquared(viewerDir.xy);
	vec3 T1 = (lenSq > 0) ? vec3(-viewerDir.y, viewerDir.x, 0) * inversesqrt(lenSq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(viewerDir, T1);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(hash.x);
	float phi = 2.0 * pi * hash.y;
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 + 0.5 * viewerDir.z;

	t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

	// Section 4.3: reprojection onto hemisphere
	vec3 normal = t1 * T1 + t2 * T2 + sqrt(max0(1.0 - t1 * t1 - t2 * t2)) * viewerDir;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	normal = normalize(vec3(alpha * normal.xy, max0(normal.z)));

	return normal;
}

#endif // UTILITY_SAMPLING_INCLUDED
