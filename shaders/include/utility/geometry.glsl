#if !defined INCLUDE_UTILITY_GEOMETRY
#define INCLUDE_UTILITY_GEOMETRY

#include "/include/utility/fast_math.glsl"

// Sphere/AABB intersection methods from https://www.scratchapixel.com

// Returns +-1
vec3 sign_non_zero(vec3 v) {
	return vec3(
		v.x >= 0.0 ? 1.0 : -1.0,
		v.y >= 0.0 ? 1.0 : -1.0,
		v.z >= 0.0 ? 1.0 : -1.0
	);
}

vec2 intersect_box(vec3 ray_origin, vec3 ray_dir, mat2x3 bounds) {
	float t_min, t_max, t_min_y, t_max_y, t_min_z, t_max_z;

	vec3  rcp_ray_dir  = rcp(ray_dir);
	ivec3 ray_dir_sign = ivec3(0.5 - 0.5 * sign_non_zero(ray_dir));

	t_min = (bounds[    ray_dir_sign.x].x - ray_origin.x) * rcp_ray_dir.x;
	t_max = (bounds[1 - ray_dir_sign.x].x - ray_origin.x) * rcp_ray_dir.x;

	if ((t_min > t_max_y) || (t_min_y > t_max))
		return vec2(-1.0);

	t_min_y = (bounds[    ray_dir_sign.y].y - ray_origin.y) * rcp_ray_dir.y;
	t_max_y = (bounds[1 - ray_dir_sign.y].y - ray_origin.y) * rcp_ray_dir.y;

	if (t_min_y > t_min)
		t_min = t_min_y;
	if (t_max_y < t_max)
		t_max = t_max_y;

	t_min_z = (bounds[    ray_dir_sign.z].z - ray_origin.z) * rcp_ray_dir.z;
	t_max_z = (bounds[1 - ray_dir_sign.z].z - ray_origin.z) * rcp_ray_dir.z;

	if ((t_min > t_max_z) || (t_min_z > t_max))
		return vec2(-1.0);
	if (t_min_z > t_min)
		t_min = t_min_z;
	if (t_max_z < t_max)
		t_max = t_max_z;

	return vec2(t_min, t_max);
}

// from https://ebruneton.github.io/precomputed_atmospheric_scattering/
vec2 intersect_sphere(float mu, float r, float sphere_radius) {
	float discriminant = r * r * (mu * mu - 1.0) + sqr(sphere_radius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -r * mu + vec2(-discriminant, discriminant);
}

vec2 intersect_sphere(vec3 ray_origin, vec3 ray_dir, float sphere_radius) {
	float b = dot(ray_origin, ray_dir);
	float discriminant = sqr(b) - dot(ray_origin, ray_origin) + sqr(sphere_radius);

	if (discriminant < 0.0) return vec2(-1.0);

	discriminant = sqrt(discriminant);
	return -b + vec2(-discriminant, discriminant);
}

vec2 intersect_spherical_shell(vec3 ray_origin, vec3 ray_dir, float inner_sphere_radius, float outer_sphere_radius) {
	vec2 inner_sphere_dists = intersect_sphere(ray_origin, ray_dir, inner_sphere_radius);
	vec2 outer_sphere_dists = intersect_sphere(ray_origin, ray_dir, outer_sphere_radius);

	bool inner_sphere_intersected = inner_sphere_dists.y >= 0.0;
	bool outer_sphere_intersected = outer_sphere_dists.y >= 0.0;

	if (!outer_sphere_intersected) return vec2(-1.0);

	vec2 dists;
	dists.x = inner_sphere_intersected && inner_sphere_dists.x < 0.0 ? inner_sphere_dists.y : max0(outer_sphere_dists.x);
	dists.y = inner_sphere_intersected && inner_sphere_dists.x > 0.0 ? inner_sphere_dists.x : outer_sphere_dists.y;

	return dists;
}

vec2 intersect_cylindrical_shell(vec3 ray_origin, vec3 ray_dir, float inner_cylinder_radius, float outer_cylinder_radius) {
	float len_o  = length(ray_origin.xz);
	float rlen_d = rcp_length(ray_dir.xz);

	float t1 = (inner_cylinder_radius - len_o) * rlen_d;
	float t2 = (outer_cylinder_radius - len_o) * rlen_d;

	return vec2(t1, t2);
}

#endif // INCLUDE_UTILITY_GEOMETRY
