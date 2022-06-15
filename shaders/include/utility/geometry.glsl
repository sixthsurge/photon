#if !defined INCLUDE_UTILITY_GEOMETRY
#define INCLUDE_UTILITY_GEOMETRY

vec2 raySphereIntersection(float mu, float r, float sphereRadius) {
	float discriminant = r * r * (mu * mu - 1.0) + sqr(sphereRadius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -r * mu + vec2(-discriminant, discriminant);
}

vec2 raySphereIntersection(vec3 rayOrigin, vec3 rayDir, float sphereRadius) {
	float b = dot(rayOrigin, rayDir);
	float discriminant = sqr(b) - dot(rayOrigin, rayOrigin) + sqr(sphereRadius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -b + vec2(-discriminant, discriminant);
}

vec2 raySphericalShellIntersection(vec3 rayOrigin, vec3 rayDir, float innerSphereRadius, float outerSphereRadius) {
	vec2 innerSphereDists = raySphereIntersection(rayOrigin, rayDir, innerSphereRadius);
	vec2 outerSphereDists = raySphereIntersection(rayOrigin, rayDir, outerSphereRadius);

	bool innerSphereIntersected = innerSphereDists.y >= 0.0;
	bool outerSphereIntersected = outerSphereDists.y >= 0.0;

	if (!outerSphereIntersected) return vec2(-1.0);

	vec2 dists;
	dists.x = innerSphereIntersected && innerSphereDists.x < 0.0 ? innerSphereDists.y : max0(outerSphereDists.x);
	dists.y = innerSphereIntersected && innerSphereDists.x > 0.0 ? innerSphereDists.x : outerSphereDists.y;

	return dists;
}

#endif // INCLUDE_UTILITY_GEOMETRY
