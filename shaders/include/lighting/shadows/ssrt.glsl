#if !defined INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS
#define INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS

#include "/include/utility/space_conversion.glsl"

bool raymarch_shadow(
	sampler2D depth_sampler,
	mat4 projection_matrix,
	mat4 projection_matrix_inverse,
	vec3 ray_origin_screen,
	vec3 ray_origin_view,
	vec3 ray_dir_view,
	bool has_sss,
	float dither,
	out float sss_depth
) {
	const uint step_count = uint(SHADOW_SSRT_STEPS);
	const float step_ratio = 2.0; // geometric sample distribution
	const float z_tolerance = 10.0; // assumed thickness in blocks

	vec3 ray_dir_screen = normalize(
		view_to_screen_space(projection_matrix, ray_origin_view + ray_dir_view, true) - ray_origin_screen
	);

	float ray_length = min_of(abs(sign(ray_dir_screen) - ray_origin_screen) / max(abs(ray_dir_screen), eps));
	      ray_length = min(ray_length, max(0.1, exp(-max0(length(ray_origin_view) * 0.025 - 1.0))));

	const float initial_step_scale = step_ratio == 1.0 
		? rcp(float(step_count)) 
		: (step_ratio - 1.0) / (pow(step_ratio, float(step_count)) - 1.0);
	float step_length = ray_length * initial_step_scale;

	vec3 ray_pos = ray_origin_screen + length(view_pixel_size) * ray_dir_screen;

	bool hit = false;
	bool hit_after_sss = false;
	bool sss_raymarch = has_sss;
	vec3 exit_pos = ray_origin_view;

	for (int i = 0; i < step_count; ++i) {
		step_length *= step_ratio;
		vec3 ray_step = ray_dir_screen * step_length;
		vec3 dithered_pos = ray_pos + dither * ray_step;
		ray_pos += ray_step;

#ifdef LOD_MOD_ACTIVE
		if (dithered_pos.z < 0.0) continue;
#endif
		if (clamp01(dithered_pos) != dithered_pos) break;

		float depth = texelFetch(depth_sampler, ivec2(dithered_pos.xy * view_res * taau_render_scale), 0).x;

		float z_ray = screen_to_view_space_depth(projection_matrix_inverse, dithered_pos.z);
		float z_sample = screen_to_view_space_depth(projection_matrix_inverse, depth);

		bool inside = depth != 0.0 && depth < dithered_pos.z && abs(z_tolerance - (z_ray - z_sample)) < z_tolerance;
		hit = inside || hit;

		if (sss_raymarch) {
			if (!inside) {
				exit_pos = dithered_pos;
				sss_raymarch = false;
			}
		} 

		else if (!sss_raymarch) {
			hit_after_sss = inside || hit_after_sss;
			if (hit) {
				break;
			}
		}
	}

	exit_pos = screen_to_view_space(projection_matrix_inverse, exit_pos, true);
	sss_depth = hit_after_sss ? -1.0 : max0(distance(ray_origin_view, exit_pos) * 0.2);

	return hit;
}

#endif // INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS
