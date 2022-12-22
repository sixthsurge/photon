#if !defined RAYTRACER_INCLUDED
#define RAYTRACER_INCLUDED

#include "/include/utility/geometry.glsl"
#include "/include/utility/space_conversion.glsl"

bool raymarch_depth_buffer(
	sampler2D depth_sampler,
	vec3 screen_pos,
	vec3 view_pos,
	vec3 view_dir,
	float dither,
	uint max_intersection_step_count,
	uint refinement_step_count,
	out vec3 hit_pos
) {
	if (view_dir.z > 0.0 && view_dir.z >= -view_pos.z) return false;
	vec3 screen_dir = normalize(view_to_screen_space(view_pos + view_dir, true) - screen_pos);

	float ray_length = intersect_box(screen_pos, screen_dir, mat2x3(vec3(0.0, 0.0, hand_depth), vec3(1.0))).y;
	uint intersection_step_count = uint(float(max_intersection_step_count) * (dampen(clamp01(ray_length)) * 0.5 + 0.5));

	float step_length = ray_length * rcp(float(intersection_step_count));

	vec3 ray_step = screen_dir * step_length;
	vec3 ray_pos = screen_pos + dither * ray_step;

	float depth_tolerance = max(4.0 * abs(ray_step.z), 0.05 * rcp_length(view_pos));

	bool hit = false;

	// Intersection loop

	for (int i = 0; i < intersection_step_count; ++i, ray_pos += ray_step) {
		float depth = texelFetch(depth_sampler, ivec2(ray_pos.xy * view_res), 0).x;

		if (depth < ray_pos.z && abs(depth_tolerance - (ray_pos.z - depth)) < depth_tolerance) {
			hit = true;
			hit_pos = ray_pos;
			break;
		}
	}

	if (!hit) return false;

	// Refinement loop

	for (int i = 0; i < refinement_step_count; ++i) {
		ray_step *= 0.5;

		float depth = texelFetch(depth_sampler, ivec2(hit_pos.xy * view_res), 0).x;

		if (depth < hit_pos.z && abs(depth_tolerance - (hit_pos.z - depth)) < depth_tolerance)
			hit_pos -= ray_step;
		else
			hit_pos += ray_step;
	}

	return true;
}

#endif // RAYTRACER_INCLUDED
