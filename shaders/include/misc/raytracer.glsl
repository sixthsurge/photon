#if !defined INCLUDE_MISC_RAYTRACER
#define INCLUDE_MISC_RAYTRACER

#include "/include/utility/geometry.glsl"
#include "/include/utility/space_conversion.glsl"

#if defined SSRT_DH 
	#define SSRT_DEPTH_SAMPLER             dhDepthTex1
	#define SSRT_PROJECTION_MATRIX         dhProjection
	#define SSRT_PROJECTION_MATRIX_INVERSE dhProjectionInverse
#else 
	#define SSRT_DEPTH_SAMPLER             combined_depth_buffer
	#define SSRT_PROJECTION_MATRIX         combined_projection_matrix
	#define SSRT_PROJECTION_MATRIX_INVERSE combined_projection_matrix_inverse
#endif

bool raymarch_depth_buffer(
	vec3 screen_pos,
	vec3 view_pos,
	vec3 view_dir,
	float dither,
	uint intersection_step_count,
	uint refinement_step_count,
	out vec3 hit_pos
) {
	if (view_dir.z > 0.0 && view_dir.z >= -view_pos.z) return false;

	vec3 screen_dir = normalize(
		view_to_screen_space(SSRT_PROJECTION_MATRIX, view_pos + view_dir, true) - screen_pos
	);

	float ray_length = min_of(abs(sign(screen_dir) - screen_pos) / max(abs(screen_dir), eps));

	float step_length = ray_length * rcp(float(intersection_step_count));

	vec3 ray_step = screen_dir * step_length;
	vec3 ray_pos = screen_pos + dither * ray_step + length(view_pixel_size) * screen_dir;

	float depth_tolerance = max(abs(ray_step.z) * 3.0, 0.02 / sqr(view_pos.z)); // from DrDesten <3

	bool hit = false;

	// Intersection loop

	for (int i = 0; i < intersection_step_count; ++i, ray_pos += ray_step) {
#ifdef DISTANT_HORIZONS
		if (ray_pos.z < 0.0) continue;
#endif
		if (clamp01(ray_pos) != ray_pos) return false;

		float depth = texelFetch(SSRT_DEPTH_SAMPLER, ivec2(ray_pos.xy * view_res * taau_render_scale), 0).x;

		if (depth < ray_pos.z && abs(depth_tolerance - (ray_pos.z - depth)) < depth_tolerance) {
			hit = true;
			hit_pos = ray_pos;
			break;
		}
	}

	if (!hit) return false;

	// Refinement loop

	float final_depth;

	for (int i = 0; i < refinement_step_count; ++i) {
		ray_step *= 0.5;

		float depth = texelFetch(SSRT_DEPTH_SAMPLER, ivec2(hit_pos.xy * view_res * taau_render_scale), 0).x;

		if (depth < hit_pos.z && abs(depth_tolerance - (hit_pos.z - depth)) < depth_tolerance)
			hit_pos -= ray_step;
		else
			hit_pos += ray_step;

		final_depth = depth;
	}

	// No intersection if the binary search landed on a sky pixel or a hand pixel
	return hand_depth < final_depth && final_depth < 1.0;
}

#endif // INCLUDE_MISC_RAYTRACER
