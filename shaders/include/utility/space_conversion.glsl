#if !defined INCLUDE_UTILITY_SPACE_CONVERSION
#define INCLUDE_UTILITY_SPACE_CONVERSION

// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
float linearize_depth(float depth) {
	return (near * far) / (depth * (near - far) + far);
}

// Approximate linear depth function by DrDesten
float linearize_depth_fast(float depth) {
	return near / (1.0 - depth);
}

float reverse_linear_depth(float linear_z) {
	return (far + near) / (far - near) + (2.0 * far * near) / (linear_z * (far - near));
}

vec3 screen_to_view_space(vec3 screen_pos, bool handle_jitter) {
	vec3 ndc_pos = 2.0 * screen_pos - 1.0;

#ifdef TAA
#ifdef TAAU
	vec2 jitter_offset = taa_offset * rcp(taau_render_scale);
#else
	vec2 jitter_offset = taa_offset * 0.75;
#endif

	if (handle_jitter) ndc_pos.xy -= jitter_offset;
#endif

	return project_and_divide(gbufferProjectionInverse, ndc_pos);
}

vec3 view_to_screen_space(vec3 view_pos, bool handle_jitter) {
	vec3 ndc_pos = project_and_divide(gbufferProjection, view_pos);

#ifdef TAA
#ifdef TAAU
	vec2 jitter_offset = taa_offset * rcp(taau_render_scale);
#else
	vec2 jitter_offset = taa_offset * 0.75;
#endif

	if (handle_jitter) ndc_pos.xy += jitter_offset;
#endif

	return ndc_pos * 0.5 + 0.5;
}

vec3 view_to_scene_space(vec3 view_pos) {
	return transform(gbufferModelViewInverse, view_pos);
}

vec3 scene_to_view_space(vec3 scene_pos) {
	return transform(gbufferModelView, scene_pos);
}

mat3 get_tbn_matrix(vec3 normal) {
	vec3 tangent = normal.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

#if defined TEMPORAL_REPROJECTION
vec3 reproject_scene_space(vec3 scene_pos, bool hand) {
	vec3 camera_offset = hand
		? vec3(0.0)
		: cameraPosition - previousCameraPosition;

	vec3 previous_pos = transform(gbufferPreviousModelView, scene_pos + camera_offset);
	     previous_pos = project_and_divide(gbufferPreviousProjection, previous_pos);

	return previous_pos * 0.5 + 0.5;
}

vec3 reproject(vec3 screen_pos) {
	vec3 pos = screen_to_view_space(screen_pos, false);
	     pos = view_to_scene_space(pos);

	bool hand = screen_pos.z < hand_depth;

	return reproject_scene_space(pos, hand);
}

vec3 reproject(vec3 screen_pos, sampler2D velocity_sampler) {
	vec3 velocity = texelFetch(velocity_sampler, ivec2(screen_pos.xy * view_res), 0).xyz;

	if (max_of(abs(velocity)) < eps) {
		return reproject(screen_pos);
	} else {
		vec3 pos = screen_to_view_space(screen_pos, false);
		     pos = pos - velocity;
		     pos = view_to_screen_space(pos, false);

		return pos;
	}
}
#endif

#endif // INCLUDE_UTILITY_SPACE_CONVERSION
