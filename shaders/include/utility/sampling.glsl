#if !defined INCLUDE_UTILITY_SAMPLING
#define INCLUDE_UTILITY_SAMPLING

vec2 vogel_disk_sample(int step_index, int step_count, float rotation) {
	const float golden_angle = 2.4;

	float r = sqrt(step_index + 0.5) / sqrt(float(step_count));
	float theta = step_index * golden_angle + rotation;

	return r * vec2(cos(theta), sin(theta));
}

vec3 uniform_sphere_sample(vec2 hash) {
	hash.x *= tau; hash.y = 2.0 * hash.y - 1.0;
	return vec3(vec2(sin(hash.x), cos(hash.x)) * sqrt(1.0 - hash.y * hash.y), hash.y);
}

vec3 uniform_hemisphere_sample(vec3 vector, vec2 hash) {
	vec3 dir = uniform_sphere_sample(hash);
	return dot(dir, vector) < 0.0 ? -dir : dir;
}

// https://amietia.com/lambertnotangent.html
vec3 cosine_weighted_hemisphere_sample(vec3 vector, vec2 hash) {
	vec3 dir = normalize(uniform_sphere_sample(hash) + vector);
	return dot(dir, vector) < 0.0 ? -dir : dir;
}

#endif // INCLUDE_UTILITY_SAMPLING
