#if !defined INCLUDE_LIGHTING_AO_SSAO 
#define INCLUDE_LIGHTING_AO_SSAO

#include "/include/utility/random.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#define SSAO_MAX_RADIUS_SCREEN 0.05

vec2 get_ssao_sample_offset(int step_index, vec2 dither) {
	float a = (float(step_index) + dither.x) * rcp(float(SSAO_STEPS));

	float r = sqr(r1(step_index, dither.y));
	float theta = a * tau;

	return r * vec2(cos(theta), sin(theta));
}

float compute_ssao(
	vec3 position_screen,
	vec3 position_view,
	vec3 normal_view,
	vec2 dither
) {
	mat3 tbn_matrix = get_tbn_matrix(normal_view);

	mat2 sample_matrix = SSAO_RADIUS * mat2(
		clamp_length(
			view_to_screen_space(
				combined_projection_matrix,
				position_view + tbn_matrix[0], 
				true
			).xy - position_screen.xy, 
			0.0, SSAO_MAX_RADIUS_SCREEN
		), 
		clamp_length(
			view_to_screen_space(
				combined_projection_matrix,
				position_view + tbn_matrix[1],
				true
			).xy - position_screen.xy, 
			0.0, SSAO_MAX_RADIUS_SCREEN
		) 
	);

	float ao = 0.0; 

	for (int i = 0; i < SSAO_STEPS; ++i) {
		vec2 sample_uv = clamp01(
			position_screen.xy + sample_matrix * get_ssao_sample_offset(i, dither)
		);

		ivec2 texel = ivec2(sample_uv * view_res * taau_render_scale + 0.5);
		float depth = texelFetch(combined_depth_buffer, texel, 0).x;

		if (depth == 1.0 || depth < hand_depth || depth == position_screen.z) continue;

		vec3 offset_view = screen_to_view_space(
			combined_projection_matrix_inverse, 
			vec3(sample_uv, depth), 
			true
		) - position_view;

		float rlen = rcp_length(offset_view);
		float cos_theta = clamp01(dot(offset_view, normal_view) * rlen);
		float distance_falloff = rcp(1.0 + rcp(rlen) * rcp(float(SSAO_RADIUS)));

		ao += cos_theta * distance_falloff;
	}

	return cube(clamp01(1.0 - ao * rcp(float(SSAO_STEPS))));
}

#endif // INCLUDE_LIGHTING_AO_SSAO

