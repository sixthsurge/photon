#if !defined UTILITY_GEOMETRY_INCLUDED
#define UTILITY_GEOMETRY_INCLUDED

// Sphere/AABB intersection methods from https://www.scratchapixel.com

// Returns +-1
vec3 signNonZero(vec3 v) {
	return vec3(
		v.x >= 0.0 ? 1.0 : -1.0,
		v.y >= 0.0 ? 1.0 : -1.0,
		v.z >= 0.0 ? 1.0 : -1.0
	);
}

vec2 intersectBox(vec3 rayOrigin, vec3 rayDir, mat2x3 bounds) {
	float tMin, tMax, tMinY, tMaxY, tMinZ, tMaxZ;

	vec3  rcpRayDir  = rcp(rayDir);
	ivec3 rayDirSign = ivec3(0.5 - 0.5 * signNonZero(rayDir));

	tMin = (bounds[    rayDirSign.x].x - rayOrigin.x) * rcpRayDir.x;
	tMax = (bounds[1 - rayDirSign.x].x - rayOrigin.x) * rcpRayDir.x;

	if ((tMin > tMaxY) || (tMinY > tMax))
		return vec2(-1.0);

	tMinY = (bounds[    rayDirSign.y].y - rayOrigin.y) * rcpRayDir.y;
	tMaxY = (bounds[1 - rayDirSign.y].y - rayOrigin.y) * rcpRayDir.y;

	if (tMinY > tMin)
		tMin = tMinY;
	if (tMaxY < tMax)
		tMax = tMaxY;

	tMinZ = (bounds[    rayDirSign.z].z - rayOrigin.z) * rcpRayDir.z;
	tMaxZ = (bounds[1 - rayDirSign.z].z - rayOrigin.z) * rcpRayDir.z;

	if ((tMin > tMaxZ) || (tMinZ > tMax))
		return vec2(-1.0);
	if (tMinZ > tMin)
		tMin = tMinZ;
	if (tMaxZ < tMax)
		tMax = tMaxZ;

	return vec2(tMin, tMax);
}

// from https://ebruneton.github.io/precomputed_atmospheric_scattering/
vec2 intersectSphere(float mu, float r, float sphereRadius) {
	float discriminant = r * r * (mu * mu - 1.0) + sqr(sphereRadius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -r * mu + vec2(-discriminant, discriminant);
}

vec2 intersectSphere(vec3 rayOrigin, vec3 rayDir, float sphereRadius) {
	float b = dot(rayOrigin, rayDir);
	float discriminant = sqr(b) - dot(rayOrigin, rayOrigin) + sqr(sphereRadius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -b + vec2(-discriminant, discriminant);
}

vec2 intersectSphericalShell(vec3 rayOrigin, vec3 rayDir, float innerSphereRadius, float outerSphereRadius) {
	vec2 innerSphereDists = intersectSphere(rayOrigin, rayDir, innerSphereRadius);
	vec2 outerSphereDists = intersectSphere(rayOrigin, rayDir, outerSphereRadius);

	bool innerSphereIntersected = innerSphereDists.y >= 0.0;
	bool outerSphereIntersected = outerSphereDists.y >= 0.0;

	if (!outerSphereIntersected) return vec2(-1.0);

	vec2 dists;
	dists.x = innerSphereIntersected && innerSphereDists.x < 0.0 ? innerSphereDists.y : max0(outerSphereDists.x);
	dists.y = innerSphereIntersected && innerSphereDists.x > 0.0 ? innerSphereDists.x : outerSphereDists.y;

	return dists;
}

#endif // UTILITY_GEOMETRY_INCLUDED
